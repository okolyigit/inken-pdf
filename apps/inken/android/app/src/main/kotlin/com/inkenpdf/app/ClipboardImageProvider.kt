package com.inkenpdf.app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/**
 * Panoya kopyalanan görseli (bölge yakalama) başka uygulamalara verir.
 * Android panosunda görsel bir `content://` URI'sidir; sağlayıcı dışa açık
 * değildir, okuma izni panodan yapıştıran uygulamaya geçici verilir
 * (`grantUriPermissions`). Yalnızca önbellekteki `clipboard/` klasöründeki
 * PNG'ler okunur. androidx `FileProvider` bağımlılığı gerekmesin diye
 * küçük bir sağlayıcı.
 */
class ClipboardImageProvider : ContentProvider() {
    companion object {
        fun authority(context: Context) = "${context.packageName}.clipboard"

        fun folder(context: Context) = File(context.cacheDir, "clipboard")

        fun uriFor(context: Context, file: File): Uri = Uri.Builder()
            .scheme("content")
            .authority(authority(context))
            .appendPath(file.name)
            .build()
    }

    override fun onCreate() = true

    private fun fileFor(uri: Uri): File {
        val context = context ?: throw FileNotFoundException()
        val name = uri.lastPathSegment ?: throw FileNotFoundException()
        val dir = folder(context)
        val file = File(dir, name)
        if (file.parentFile?.canonicalPath != dir.canonicalPath || !file.isFile) {
            throw FileNotFoundException(uri.toString())
        }
        return file
    }

    override fun getType(uri: Uri) = "image/png"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("yalnızca okuma")
        return ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val file = fileFor(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columns)
        cursor.addRow(
            columns.map {
                when (it) {
                    OpenableColumns.DISPLAY_NAME -> file.name
                    OpenableColumns.SIZE -> file.length()
                    else -> null
                }
            },
        )
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0
}
