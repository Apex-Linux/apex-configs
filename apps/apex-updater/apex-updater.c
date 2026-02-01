#include <adwaita.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
    AdwApplication *app;
    GtkWidget *window;
    GtkWidget *stack;
    GtkWidget *spinner;
    GtkWidget *update_btn;
    GtkWidget *subtitle_label;
    GtkTextBuffer *log_buffer;
    GtkWidget *log_view;
    char *pending_apps;
} ApexUpdater;

static void apply_custom_styles() {
    GtkCssProvider *provider = gtk_css_provider_new();
    const char *css =
        "window, statuspage { background: linear-gradient(180deg, #0f0c29 0%, #302b63 50%, #24243e 100%); }"
        ".glow-title { color: #00d2ff; font-weight: bold; font-size: 30px; text-shadow: 0px 0px 15px rgba(0, 210, 255, 0.8); margin-top: 5px; }"
        ".subtitle { color: #00ffcc; font-size: 14px; font-weight: 500; text-shadow: 0px 0px 10px rgba(0, 255, 204, 0.4); margin-bottom: 30px; }"
        "button.suggested-action { "
        "  background: linear-gradient(to bottom, #00ffcc, #00d2ff); "
        "  color: #000000; font-weight: bold; border-radius: 99px; padding: 12px 40px; "
        "  box-shadow: 0px 4px 15px rgba(0, 255, 204, 0.3); border: none; "
        "}"
        "button.suggested-action:hover { box-shadow: 0px 0px 20px rgba(0, 255, 204, 0.6); }"
        "textview.log-view text { font-family: 'Monospace', monospace; color: #00ff00; background-color: #000000; padding: 15px; font-size: 10pt; }";

    gtk_css_provider_load_from_string(provider, css);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

// THIS SENDS THE DESKTOP NOTIFICATION
static void send_update_notification(ApexUpdater *app_data) {
    GNotification *notification = g_notification_new("Apex Linux Updates");
    g_notification_set_body(notification, "New system updates are available.");
    g_notification_set_priority(notification, G_NOTIFICATION_PRIORITY_NORMAL);
    GIcon *icon = g_themed_icon_new("software-update-available-symbolic");
    g_notification_set_icon(notification, icon);
    g_application_send_notification(G_APPLICATION(app_data->app), "apex-update-available", notification);
    g_object_unref(icon);
    g_object_unref(notification);
}

static void read_proc_out(GObject *source, GAsyncResult *res, gpointer user_data) {
    ApexUpdater *app = (ApexUpdater *)user_data;
    char buffer[4096];
    g_autoptr(GError) error = NULL;
    gssize n_read = g_input_stream_read_finish(G_INPUT_STREAM(source), res, &error);
    if (n_read > 0) {
        GtkTextIter end;
        gtk_text_buffer_get_end_iter(app->log_buffer, &end);
        gtk_text_buffer_insert(app->log_buffer, &end, buffer, n_read);
        GtkTextMark *mark = gtk_text_buffer_get_insert(app->log_buffer);
        if (app->log_view) gtk_text_view_scroll_to_mark(GTK_TEXT_VIEW(app->log_view), mark, 0.0, TRUE, 0.5, 1.0);
        g_input_stream_read_async(G_INPUT_STREAM(source), buffer, sizeof(buffer), G_PRIORITY_DEFAULT, NULL, (GAsyncReadyCallback)read_proc_out, app);
    }
}

static void show_log_popup(ApexUpdater *app) {
    GtkWidget *log_window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(log_window), "Apex Update Manifest");
    gtk_window_set_default_size(GTK_WINDOW(log_window), 700, 500);
    gtk_window_set_transient_for(GTK_WINDOW(log_window), GTK_WINDOW(app->window));
    gtk_window_set_modal(GTK_WINDOW(log_window), TRUE);
    GtkWidget *scroll = gtk_scrolled_window_new();
    app->log_view = gtk_text_view_new_with_buffer(app->log_buffer);
    gtk_widget_add_css_class(app->log_view, "log-view");
    gtk_text_view_set_editable(GTK_TEXT_VIEW(app->log_view), FALSE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroll), app->log_view);
    gtk_window_set_child(GTK_WINDOW(log_window), scroll);
    gtk_window_present(GTK_WINDOW(log_window));
}

// THIS CHECKS FOR UPDATES AND REVEALS THE BUTTON
static void fetch_update_list(ApexUpdater *app) {
    g_autoptr(GError) error = NULL;
    g_autofree char *stdout_buf = NULL;
    GSubprocess *proc = g_subprocess_new(G_SUBPROCESS_FLAGS_STDOUT_PIPE, &error, "dnf", "check-update", NULL);
    if (proc) {
        g_subprocess_communicate_utf8(proc, NULL, NULL, &stdout_buf, NULL, &error);
        if (stdout_buf && strlen(stdout_buf) > 10) {
            app->pending_apps = g_strdup(stdout_buf);
            send_update_notification(app);
            gtk_widget_set_visible(app->update_btn, TRUE); // <--- SHOWS BUTTON
            gtk_label_set_text(GTK_LABEL(app->subtitle_label), "New updates are ready to install");
        } else {
            app->pending_apps = g_strdup("All packages are up to date.");
            gtk_widget_set_visible(app->update_btn, FALSE); // <--- HIDES BUTTON
            gtk_label_set_text(GTK_LABEL(app->subtitle_label), "Your system is currently up to date");
        }
        gtk_text_buffer_set_text(app->log_buffer, app->pending_apps, -1);
    }
}

static void on_update_finished(GObject *source, GAsyncResult *res, gpointer user_data) {
    ApexUpdater *app = (ApexUpdater *)user_data;
    g_subprocess_wait_finish(G_SUBPROCESS(source), res, NULL);
    gtk_stack_set_visible_child_name(GTK_STACK(app->stack), "done_page");
    gtk_spinner_stop(GTK_SPINNER(app->spinner));
}

static void run_real_update(ApexUpdater *app) {
    gtk_stack_set_visible_child_name(GTK_STACK(app->stack), "work_page");
    gtk_spinner_start(GTK_SPINNER(app->spinner));
    GSubprocess *proc = g_subprocess_new(G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_PIPE,
                                        NULL, "pkexec", "dnf", "update", "-y", NULL);
    if (proc) {
        GInputStream *stdout_stream = g_subprocess_get_stdout_pipe(proc);
        static char buf_out[4096];
        g_input_stream_read_async(stdout_stream, buf_out, sizeof(buf_out), G_PRIORITY_DEFAULT, NULL, (GAsyncReadyCallback)read_proc_out, app);
        g_subprocess_wait_async(proc, NULL, on_update_finished, app);
    }
}

static void on_dialog_response(AdwAlertDialog *self, gchar *response, gpointer user_data) {
    ApexUpdater *app = (ApexUpdater *)user_data;
    if (g_strcmp0(response, "start") == 0) run_real_update(app);
    else if (g_strcmp0(response, "logs") == 0) show_log_popup(app);
}

// THIS SHOWS THE POP-UP DIALOG
static void show_update_popup(GtkButton *btn, gpointer user_data) {
    ApexUpdater *app = (ApexUpdater *)user_data;
    AdwDialog *dialog = adw_alert_dialog_new("System Update", "Apex Linux update is ready.");
    adw_alert_dialog_add_responses(ADW_ALERT_DIALOG(dialog), "cancel", "Cancel", "logs", "View Details", "start", "Install Now", NULL);
    adw_alert_dialog_set_response_appearance(ADW_ALERT_DIALOG(dialog), "start", ADW_RESPONSE_SUGGESTED);
    g_signal_connect(dialog, "response", G_CALLBACK(on_dialog_response), app);
    adw_dialog_present(dialog, GTK_WIDGET(app->window));
}

static void go_back_to_start(GtkButton *btn, gpointer user_data) {
    ApexUpdater *app = (ApexUpdater *)user_data;
    gtk_stack_set_visible_child_name(GTK_STACK(app->stack), "start_page");
    fetch_update_list(app);
}

static void activate(AdwApplication *adw_app) {
    ApexUpdater *app = g_new0(ApexUpdater, 1);
    app->app = adw_app;
    app->log_buffer = gtk_text_buffer_new(NULL);
    adw_style_manager_set_color_scheme(adw_style_manager_get_default(), ADW_COLOR_SCHEME_PREFER_DARK);
    apply_custom_styles();

    app->window = adw_application_window_new(GTK_APPLICATION(adw_app));
    gtk_window_set_default_size(GTK_WINDOW(app->window), 500, 600);

    g_autofree char *exe_path = g_file_read_link("/proc/self/exe", NULL);
    g_autofree char *logo_path = g_build_filename(g_path_get_dirname(exe_path), "logo.png", NULL);

    app->stack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(app->stack), GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN);

    GtkWidget *main_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_halign(main_box, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(main_box, GTK_ALIGN_CENTER);

    GtkWidget *logo = gtk_picture_new_for_filename(logo_path);
    gtk_picture_set_content_fit(GTK_PICTURE(logo), GTK_CONTENT_FIT_CONTAIN);
    gtk_widget_set_size_request(logo, 32, 32);
    gtk_widget_set_halign(logo, GTK_ALIGN_CENTER);
    gtk_widget_set_margin_top(logo, -300);
    gtk_widget_set_margin_bottom(logo, 10);
    gtk_box_append(GTK_BOX(main_box), logo);

    GtkWidget *title = gtk_label_new("System Update");
    gtk_widget_add_css_class(title, "glow-title");
    gtk_widget_set_margin_top(title, -100);
    gtk_widget_set_margin_bottom(title, 15);
    gtk_box_append(GTK_BOX(main_box), title);

    app->subtitle_label = gtk_label_new("Checking for updates...");
    gtk_widget_add_css_class(app->subtitle_label, "subtitle");
    gtk_widget_set_margin_top(app->subtitle_label, 5);
    gtk_box_append(GTK_BOX(main_box), app->subtitle_label);

    app->update_btn = gtk_button_new_with_label("Update Now");
    gtk_widget_add_css_class(app->update_btn, "suggested-action");
    gtk_widget_set_halign(app->update_btn, GTK_ALIGN_CENTER);
    gtk_widget_set_visible(app->update_btn, FALSE); // INVISIBLE BY DEFAULT
    g_signal_connect(app->update_btn, "clicked", G_CALLBACK(show_update_popup), app);
    gtk_box_append(GTK_BOX(main_box), app->update_btn);

    GtkWidget *start_page = adw_status_page_new();
    adw_status_page_set_child(ADW_STATUS_PAGE(start_page), main_box);

    GtkWidget *work_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20);
    gtk_widget_set_halign(work_box, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(work_box, GTK_ALIGN_CENTER);
    app->spinner = gtk_spinner_new();
    gtk_widget_set_size_request(app->spinner, 64, 64);
    gtk_box_append(GTK_BOX(work_box), app->spinner);
    GtkWidget *work_page = adw_status_page_new();
    adw_status_page_set_child(ADW_STATUS_PAGE(work_page), work_box);

    GtkWidget *done_page = adw_status_page_new();
    adw_status_page_set_title(ADW_STATUS_PAGE(done_page), "System Up to Date");
    GtkWidget *finish_btn = gtk_button_new_with_label("Finish");
    gtk_widget_set_halign(finish_btn, GTK_ALIGN_CENTER);
    g_signal_connect(finish_btn, "clicked", G_CALLBACK(go_back_to_start), app);
    adw_status_page_set_child(ADW_STATUS_PAGE(done_page), finish_btn);

    gtk_stack_add_named(GTK_STACK(app->stack), start_page, "start_page");
    gtk_stack_add_named(GTK_STACK(app->stack), work_page, "work_page");
    gtk_stack_add_named(GTK_STACK(app->stack), done_page, "done_page");

    adw_application_window_set_content(ADW_APPLICATION_WINDOW(app->window), app->stack);
    fetch_update_list(app);
    gtk_window_present(GTK_WINDOW(app->window));
}

int main(int argc, char *argv[]) {
    g_autoptr(AdwApplication) app = adw_application_new("io.apex.updater", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    return g_application_run(G_APPLICATION(app), argc, argv);
}
