package com.inkenpdf.app

import android.app.Activity
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.os.Process
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.content.Context
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Android'de dosyalar SAF (Storage Access Framework) ile açılır ve kaydedilir.
 *
 * Kanal `inken/documents`. Büyük içerik kanaldan geçmez: okunan belge
 * önbellekte geçici bir dosyaya kopyalanır (Dart okuyup siler), yazılacak
 * belge de Dart'ın önbelleğe yazdığı dosyadan URI'ye kopyalanır.
 *
 * Açılan ve oluşturulan URI'lerin izni kalıcı alınır: uygulama yeniden
 * açılınca (otomatik yedekten kurtarma) aynı dosyaya yine yazılabilir.
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var pendingRequest = 0
    private var documents: MethodChannel? = null

    /** Başka bir uygulamadan "Birlikte aç" ile gelen, Dart'ın henüz almadığı PDF. */
    private var incoming: Uri? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Yeniden kurulan etkinlik (süreç öldürülüp geri gelince) aynı
        // niyeti yine alır; dosya ikinci kez açılmasın.
        if (savedInstanceState == null) accept(intent)
    }

    /** Uygulama açıkken gelen dosya (singleTask): Dart'a haber verilir. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (accept(intent)) documents?.invokeMethod("incomingAvailable", null)
    }

    private fun accept(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_VIEW) return false
        incoming = intent.data ?: return false
        return true
    }

    /**
     * Gelen dosyayı verir ve unutur. Kalıcı izin yalnızca gönderen izin
     * verdiyse alınır; yoksa okuma / yazma izni bu çalıştırmayla sınırlıdır.
     */
    private fun takeIncoming(result: MethodChannel.Result) {
        val uri = incoming ?: return result.success(null)
        incoming = null
        val writable = persist(uri) || checkUriPermission(
            uri,
            Process.myPid(),
            Process.myUid(),
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        ) == PackageManager.PERMISSION_GRANTED
        background(result) {
            mapOf("uri" to uri.toString(), "name" to displayName(uri), "writable" to writable)
        }
    }

    /**
     * Samsung S Pen: yan düğme basılıyken kalem olayları Android'in standart
     * eylem kodları yerine Samsung'un kodlarıyla gelir (211 aşağı, 212 yukarı,
     * 213 hareket, 214 iptal). Flutter bunları tanımaz ve atar: düğme
     * basılıyken kalem hiçbir şey yapmazdı. Standart koda çevrilir ve düğme
     * durumuna BUTTON_STYLUS_PRIMARY eklenir; Flutter'da kalem düğmesi
     * (kPrimaryStylusButton) olarak görünür, Inken silgi olarak kullanır.
     */
    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        val fixed = samsungPenEvent(ev) ?: return super.dispatchTouchEvent(ev)
        try {
            return super.dispatchTouchEvent(fixed)
        } finally {
            fixed.recycle()
        }
    }

    private fun samsungPenEvent(ev: MotionEvent): MotionEvent? {
        val action = when (ev.actionMasked) {
            SPEN_ACTION_DOWN -> MotionEvent.ACTION_DOWN
            SPEN_ACTION_UP -> MotionEvent.ACTION_UP
            SPEN_ACTION_MOVE -> MotionEvent.ACTION_MOVE
            SPEN_ACTION_CANCEL -> MotionEvent.ACTION_CANCEL
            else -> return null
        }
        val n = ev.pointerCount
        val properties = Array(n) { i ->
            MotionEvent.PointerProperties().also { ev.getPointerProperties(i, it) }
        }
        val coords = Array(n) { i ->
            MotionEvent.PointerCoords().also { ev.getPointerCoords(i, it) }
        }
        return MotionEvent.obtain(
            ev.downTime,
            ev.eventTime,
            action,
            n,
            properties,
            coords,
            ev.metaState,
            ev.buttonState or MotionEvent.BUTTON_STYLUS_PRIMARY,
            ev.xPrecision,
            ev.yPrecision,
            ev.deviceId,
            ev.edgeFlags,
            ev.source,
            ev.flags,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        documents = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inken/documents")
            .also { it.setMethodCallHandler(::onCall) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inken/print")
            .setMethodCallHandler(::onPrint)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inken/clipboard")
            .setMethodCallHandler(::onClipboard)
    }

    /**
     * Pano: Flutter'ın Clipboard'ı yalnızca metin okur. Panodaki görsel bir
     * `content://` URI'sidir; baytları G/Ç iş parçacığında okunur ve olduğu
     * gibi (PNG, JPEG…) döner. Görsel yoksa `null`.
     */
    private fun onClipboard(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "readImage") return result.notImplemented()
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = manager.primaryClip
        val uri = clip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
        if (uri == null) return result.success(null)
        val type = contentResolver.getType(uri)
            ?: clip.description?.takeIf { it.mimeTypeCount > 0 }?.getMimeType(0)
        if (type != null && !type.startsWith("image/")) return result.success(null)
        background(result) {
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        }
    }

    /**
     * Yazdırma: Dart'ın önbelleğe yazdığı (çizimleri gömülü) PDF sistemin
     * yazdırma servisine verilir; önizleme, yazıcı, sayfa aralığı sistemde.
     * Yanıt hemen "started" döner (iş sistemin kuyruğunda sürer); dosya iş
     * bitince silinir.
     */
    private fun onPrint(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "print") return result.notImplemented()
        val path = call.argument<String>("path")
            ?: return result.error("bad_args", "path gerekli", null)
        val title = call.argument<String>("title") ?: "Inken PDF"
        val file = File(path)
        val manager = getSystemService(Context.PRINT_SERVICE) as PrintManager
        manager.print(title, PdfFileAdapter(file, title), null)
        result.success("started")
    }

    private class PdfFileAdapter(private val file: File, private val title: String) :
        PrintDocumentAdapter() {
        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes,
            cancellationSignal: CancellationSignal?,
            callback: LayoutResultCallback,
            extras: Bundle?,
        ) {
            if (cancellationSignal?.isCanceled == true) return callback.onLayoutCancelled()
            val info = PrintDocumentInfo.Builder(title)
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .setPageCount(PrintDocumentInfo.PAGE_COUNT_UNKNOWN)
                .build()
            callback.onLayoutFinished(info, oldAttributes != newAttributes)
        }

        override fun onWrite(
            pages: Array<out PageRange>?,
            destination: ParcelFileDescriptor,
            cancellationSignal: CancellationSignal?,
            callback: WriteResultCallback,
        ) {
            try {
                file.inputStream().use { input ->
                    FileOutputStream(destination.fileDescriptor).use { input.copyTo(it) }
                }
                callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            } catch (e: IOException) {
                callback.onWriteFailed(e.message)
            }
        }

        override fun onFinish() {
            file.delete()
        }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> startPicker(REQUEST_OPEN, result) {
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/pdf")
            }
            "create" -> startPicker(REQUEST_CREATE, result) {
                Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/pdf")
                    .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
            }
            "read" -> background(result) {
                copyToCache(Uri.parse(call.argument<String>("uri")!!))
            }
            "write" -> background(result) {
                write(Uri.parse(call.argument<String>("uri")!!), File(call.argument<String>("path")!!))
                null
            }
            "stat" -> background(result) { stat(Uri.parse(call.argument<String>("uri")!!)) }
            "name" -> background(result) { displayName(Uri.parse(call.argument<String>("uri")!!)) }
            "takeIncoming" -> takeIncoming(result)
            // Yalnızca entegrasyon testleri için: seçici olmadan bir content://
            // belgesi (İndirilenler'de) oluşturur.
            "debugCreateDownload" -> background(result) {
                val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                if (!debuggable || Build.VERSION.SDK_INT < 29) {
                    throw UnsupportedOperationException("yalnızca hata ayıklama, API 29+")
                }
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, call.argument<String>("name"))
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                }
                contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)!!.toString()
            }
            "debugDelete" -> background(result) {
                contentResolver.delete(Uri.parse(call.argument<String>("uri")!!), null, null)
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun startPicker(request: Int, result: MethodChannel.Result, intent: () -> Intent) {
        if (pending != null) {
            result.error("busy", "Başka bir dosya seçici açık", null)
            return
        }
        pending = result
        pendingRequest = request
        startActivityForResult(intent(), request)
    }

    @Deprecated("FlutterActivity bir ComponentActivity değil; eski API gerekli")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pending ?: return
        if (requestCode != pendingRequest) return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val writable = persist(uri)
        background(result) {
            val name = displayName(uri)
            when (requestCode) {
                REQUEST_OPEN -> mapOf(
                    "uri" to uri.toString(),
                    "name" to name,
                    "path" to copyToCache(uri),
                    "writable" to writable,
                )
                else -> mapOf("uri" to uri.toString(), "name" to name)
            }
        }
    }

    /** Kalıcı izin alır; yazma izni alınabildiyse `true`. */
    private fun persist(uri: Uri): Boolean {
        val rw = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        return try {
            contentResolver.takePersistableUriPermission(uri, rw)
            true
        } catch (e: SecurityException) {
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: SecurityException) {
            }
            false
        }
    }

    private fun copyToCache(uri: Uri): String {
        val out = File(cacheDir, "inken-open-${UUID.randomUUID()}.pdf")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Dosya okunamadı: $uri" }
            out.outputStream().use { input.copyTo(it) }
        }
        return out.path
    }

    /**
     * [source]'u [uri]'ye yazar. SAF'ta yeniden adlandırma olmadığından
     * yazma yerinde yapılır; baytlar önceden hazır olduğundan yarım kalma
     * aralığı kısadır.
     *
     * Bazı sağlayıcılar (MediaStore dahil) "wt" kipinde dosyayı kısaltmaz;
     * eski içeriğin kuyruğu kalır ve PDF bozulur. Bu yüzden önce dosya
     * tanımlayıcısıyla yazılıp açıkça kısaltılır ve boyut tanımlayıcıdan
     * doğrulanır. Tanımlayıcı aranabilir değilse (bulut sağlayıcıları, boru)
     * akışla "wt" yazılır.
     */
    private fun write(uri: Uri, source: File) {
        val length = source.length()
        val viaDescriptor = try {
            contentResolver.openFileDescriptor(uri, "rw")?.use { pfd ->
                FileOutputStream(pfd.fileDescriptor).use { out ->
                    val channel = out.channel
                    channel.truncate(0)
                    channel.position(0)
                    source.inputStream().use { it.copyTo(out) }
                    out.flush()
                    channel.truncate(length)
                    channel.force(true)
                }
                val size = pfd.statSize
                if (size >= 0 && size != length) {
                    throw IllegalStateException("Yazılan boyut tutmuyor: $size != $length")
                }
                true
            } ?: false
        } catch (e: IOException) {
            // Aranamayan tanımlayıcı (boru): akışla dene.
            false
        } catch (e: IllegalArgumentException) {
            false
        } catch (e: UnsupportedOperationException) {
            false
        }
        if (viaDescriptor) return
        val stream = try {
            contentResolver.openOutputStream(uri, "wt")
        } catch (e: IllegalArgumentException) {
            contentResolver.openOutputStream(uri, "w")
        }
        requireNotNull(stream) { "Dosyaya yazılamadı: $uri" }.use { out ->
            source.inputStream().use { it.copyTo(out) }
        }
    }

    /** Boyut ve (biliniyorsa) değiştirilme zamanı; dosya yoksa `null`. */
    private fun stat(uri: Uri): Map<String, Any?>? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (!c.moveToFirst()) return null
                val size = c.getColumnIndex(OpenableColumns.SIZE)
                val modified = c.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                mapOf(
                    "size" to if (size >= 0 && !c.isNull(size)) c.getLong(size) else -1L,
                    "modified" to if (modified >= 0 && !c.isNull(modified)) c.getLong(modified) else null,
                )
            }
        } catch (e: SecurityException) {
            null
        } catch (e: FileNotFoundException) {
            null
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) return c.getString(0)
            }
        } catch (_: Exception) {
        }
        return uri.lastPathSegment ?: "belge.pdf"
    }

    /** [work]'ü G/Ç iş parçacığında çalıştırır, sonucu ana iş parçacığında döner. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error(e.javaClass.simpleName, e.message, null) }
            }
        }
    }

    companion object {
        // Samsung S Pen SDK'sindeki eylem kodları (yan düğme basılıyken).
        private const val SPEN_ACTION_DOWN = 211
        private const val SPEN_ACTION_UP = 212
        private const val SPEN_ACTION_MOVE = 213
        private const val SPEN_ACTION_CANCEL = 214
        private const val REQUEST_OPEN = 4101
        private const val REQUEST_CREATE = 4102
    }
}
