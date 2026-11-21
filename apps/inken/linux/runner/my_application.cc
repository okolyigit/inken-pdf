#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtkunixprint.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // Dart'tan pencere başlığı: "inken/window" kanalı, "setTitle".
  FlMethodChannel* window_channel;
  // Yazdırma: "inken/print" kanalı, "print" {path, title}.
  FlMethodChannel* print_channel;
  // Pano: "inken/clipboard" kanalı, "readImage" → PNG baytları ya da null.
  FlMethodChannel* clipboard_channel;
};

// ---- pano
//
// Flutter'ın Clipboard'ı yalnızca metin okur. Panodaki görsel (ekran
// görüntüsü, tarayıcıdan "Resmi kopyala") GTK ile alınır; GTK, sunulan
// biçimi (image/png, image/bmp, image/jpeg…) kendisi çözer. Dart'a PNG
// olarak verilir. X11 ve Wayland'da aynı.

static void clipboard_image_cb(GtkClipboard* clipboard, GdkPixbuf* pixbuf,
                               gpointer user_data) {
  g_autoptr(FlMethodCall) call = FL_METHOD_CALL(user_data);
  if (pixbuf == nullptr) {
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }
  gchar* buffer = nullptr;
  gsize size = 0;
  g_autoptr(GError) error = nullptr;
  if (!gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &size, "png", &error,
                                 nullptr)) {
    fl_method_call_respond_error(call, "clipboard_failed", error->message,
                                 nullptr, nullptr);
    return;
  }
  g_autoptr(FlValue) result =
      fl_value_new_uint8_list(reinterpret_cast<const uint8_t*>(buffer), size);
  g_free(buffer);
  fl_method_call_respond_success(call, result, nullptr);
}

static void clipboard_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                                gpointer user_data) {
  if (g_strcmp0(fl_method_call_get_name(call), "readImage") != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(call, response, nullptr);
    return;
  }
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  // Yanıt geri çağrıda verilir; çağrı o zamana kadar tutulur.
  gtk_clipboard_request_image(clipboard, clipboard_image_cb,
                              g_object_ref(call));
}

// ---- yazdırma
//
// Çizimleri gömülü PDF (Dart üretir) sistemin yazdırma penceresinden
// doğrudan CUPS'a gönderilir: GtkPrintUnixDialog yazıcı / sayfa aralığı /
// kopya seçtirir, GtkPrintJob dosyayı olduğu gibi yollar (CUPS PDF'i kendisi
// işler). Sayfaları yeniden çizmeye ve ikinci bir PDF kitaplığına gerek
// kalmaz. Yanıt: "printed", "cancelled" ya da hata.

typedef struct {
  FlMethodCall* call;
  gchar* path;
  gchar* title;
} PrintRequest;

static void print_request_free(PrintRequest* r) {
  g_object_unref(r->call);
  g_free(r->path);
  g_free(r->title);
  g_free(r);
}

static void respond_string(FlMethodCall* call, const gchar* value) {
  g_autoptr(FlValue) result = fl_value_new_string(value);
  fl_method_call_respond_success(call, result, nullptr);
}

// İş, gönderim bitene kadar burada tutulan referansla yaşar.
static void print_job_done_cb(GtkPrintJob* job, gpointer user_data,
                              const GError* error) {
  FlMethodCall* call = FL_METHOD_CALL(user_data);
  g_object_unref(job);
  if (error != nullptr) {
    fl_method_call_respond_error(call, "print_failed", error->message,
                                 nullptr, nullptr);
  } else {
    respond_string(call, "printed");
  }
}

static void print_dialog_response_cb(GtkDialog* dialog, gint response,
                                     gpointer user_data) {
  PrintRequest* r = static_cast<PrintRequest*>(user_data);
  GtkPrintUnixDialog* unix_dialog = GTK_PRINT_UNIX_DIALOG(dialog);
  if (response != GTK_RESPONSE_OK) {
    respond_string(r->call, "cancelled");
  } else {
    GtkPrinter* printer = gtk_print_unix_dialog_get_selected_printer(
        unix_dialog);
    if (printer == nullptr || !gtk_printer_accepts_pdf(printer)) {
      fl_method_call_respond_error(r->call, "printer_unsupported",
                                   "Yazıcı PDF kabul etmiyor", nullptr,
                                   nullptr);
    } else {
      g_autoptr(GtkPrintSettings) settings =
          gtk_print_unix_dialog_get_settings(unix_dialog);
      GtkPageSetup* page_setup =
          gtk_print_unix_dialog_get_page_setup(unix_dialog);
      GtkPrintJob* job =
          gtk_print_job_new(r->title, printer, settings, page_setup);
      g_autoptr(GError) error = nullptr;
      if (!gtk_print_job_set_source_file(job, r->path, &error)) {
        g_object_unref(job);
        fl_method_call_respond_error(r->call, "print_failed", error->message,
                                     nullptr, nullptr);
      } else {
        gtk_print_job_send(job, print_job_done_cb, g_object_ref(r->call),
                           g_object_unref);
      }
    }
  }
  gtk_widget_destroy(GTK_WIDGET(dialog));
  print_request_free(r);
}

static void print_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                            gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  if (g_strcmp0(fl_method_call_get_name(call), "print") != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(call, response, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(call);
  FlValue* path = args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP
                      ? nullptr
                      : fl_value_lookup_string(args, "path");
  FlValue* title = path == nullptr ? nullptr
                                   : fl_value_lookup_string(args, "title");
  if (path == nullptr || fl_value_get_type(path) != FL_VALUE_TYPE_STRING) {
    fl_method_call_respond_error(call, "bad_args", "path gerekli", nullptr,
                                 nullptr);
    return;
  }
  PrintRequest* r = g_new0(PrintRequest, 1);
  r->call = FL_METHOD_CALL(g_object_ref(call));
  r->path = g_strdup(fl_value_get_string(path));
  r->title = g_strdup(title != nullptr &&
                              fl_value_get_type(title) == FL_VALUE_TYPE_STRING
                          ? fl_value_get_string(title)
                          : "Inken PDF");
  GtkWidget* dialog = gtk_print_unix_dialog_new(nullptr, window);
  // Sayfa aralığı ve kopyalar CUPS'ta; uygulama kendisi bir şey yapmaz.
  gtk_print_unix_dialog_set_manual_capabilities(
      GTK_PRINT_UNIX_DIALOG(dialog), static_cast<GtkPrintCapabilities>(0));
  gtk_print_unix_dialog_set_embed_page_setup(GTK_PRINT_UNIX_DIALOG(dialog),
                                             TRUE);
  g_signal_connect(dialog, "response", G_CALLBACK(print_dialog_response_cb),
                   r);
  gtk_window_set_modal(GTK_WINDOW(dialog), TRUE);
  gtk_widget_show(dialog);
}

static void window_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                             gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(call), "setTitle") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      const gchar* title = fl_value_get_string(args);
      gtk_window_set_title(window, title);
      GtkWidget* bar = gtk_window_get_titlebar(window);
      if (bar != nullptr && GTK_IS_HEADER_BAR(bar)) {
        gtk_header_bar_set_title(GTK_HEADER_BAR(bar), title);
      }
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(fl_method_call_get_name(call), "setFullscreen") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL) {
      if (fl_value_get_bool(args)) {
        gtk_window_fullscreen(window);
      } else {
        gtk_window_unfullscreen(window);
      }
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Sistemin kendi ince pencere başlık çubuğunu kullan (KDE Wayland / KWin,
  // XFCE, X11 pencere yöneticileri). İstemci tarafı başlık çubuğu (CSD) zorunlu
  // olan ortamlarda (ör. GNOME Wayland) GTK'nın oluşturduğu çubuk da CSS ile
  // inceltilir.
  gtk_window_set_title(window, "Inken PDF");
  GdkScreen* screen = gtk_window_get_screen(window);
  if (screen != nullptr) {
    g_autoptr(GtkCssProvider) css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(
        css,
        "headerbar, .titlebar {"
        "  min-height: 28px;"
        "  padding-top: 2px;"
        "  padding-bottom: 2px;"
        "}"
        "headerbar button.titlebutton, .titlebar button.titlebutton {"
        "  min-height: 22px;"
        "  min-width: 22px;"
        "  padding: 2px;"
        "  margin: 0;"
        "}",
        -1, nullptr);
    gtk_style_context_add_provider_for_screen(
        screen, GTK_STYLE_PROVIDER(css),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  gtk_window_set_default_size(window, 1280, 720);

  // Pencere ikonu: paketlenmiş varlıklardan (assets/brand/inken-icon-256.png).
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe != nullptr) {
    g_autofree gchar* dir = g_path_get_dirname(exe);
    g_autofree gchar* icon = g_build_filename(
        dir, "data", "flutter_assets", "assets", "brand", "inken-icon-256.png",
        nullptr);
    gtk_window_set_icon_from_file(window, icon, nullptr);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "inken/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_cb, window, nullptr);
  self->print_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "inken/print",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->print_channel,
                                            print_method_cb, window, nullptr);
  self->clipboard_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "inken/clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->clipboard_channel, clipboard_method_cb, nullptr, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  g_clear_object(&self->print_channel);
  g_clear_object(&self->clipboard_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
