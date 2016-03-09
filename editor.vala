class Reporter : Vala.Report {
    public override void depr (Vala.SourceReference? source, string message) {
        GLib.message (@"Deprecated: $message");
        ++warnings;
    }
    public override void err (Vala.SourceReference? source, string message) {
        GLib.message (@"Error: $message");
        ++errors;
    }
    public override void note (Vala.SourceReference? source, string message) {
        GLib.message (@"Note: $message");
        ++warnings;
    }
    public override void warn (Vala.SourceReference? source, string message) {
        GLib.message (@"Warning: $message");
        ++warnings;
    }
}

void vala_stuff (string filename) {
    var ctx = new Vala.CodeContext ();
    Vala.CodeContext.push (ctx);

    for (int i = 2; i <= 30; i += 2) {
        ctx.add_define ("VALA_0_%d".printf (i));
    }
    ctx.target_glib_major = 2;
    ctx.target_glib_major = 44;
    for (int i = 16; i <= ctx.target_glib_major; i += 2) {
        ctx.add_define ("GLIB_2_%d".printf (i));
    }
    ctx.report = new Reporter ();
    ctx.add_external_package ("glib-2.0");
    ctx.add_external_package ("gobject-2.0");
    ctx.add_external_package ("gtk+-3.0");
    ctx.add_external_package ("gtksourceview-3.0");
    ctx.add_external_package ("libvala-0.30");
    ctx.profile = Vala.Profile.GOBJECT;

    print ("========== adding files ==============\n");

    ctx.add_source_filename (filename);
    print ("%d errors, %d warnings\n", ctx.report.get_errors (), ctx.report.get_warnings ());

    print ("========== parsing ==============\n");

    var parser = new Vala.Parser ();
    parser.parse (ctx);
    print ("%d errors, %d warnings\n", ctx.report.get_errors (), ctx.report.get_warnings ());

    print ("========== checking ==============\n");

    ctx.check ();
    print ("%d errors, %d warnings\n", ctx.report.get_errors (), ctx.report.get_warnings ());

    Vala.CodeContext.pop ();
}

[GtkTemplate (ui = "/me/iofel/vala-editor/ui.glade")]
public class MainWindow : Gtk.ApplicationWindow {
    [GtkChild] Gtk.FileChooserButton filechooser;
    [GtkChild] Gtk.Entry packages_entry;
    [GtkChild] Gtk.SourceView srcview;
    [GtkChild] Gtk.TreeView symboltree;

    public MainWindow (Gtk.Application a) {
        Object (application: a);
        set_default_size (800, 600);

        ((Gtk.SourceBuffer) srcview.buffer).language = Gtk.SourceLanguageManager.get_default ().get_language ("vala");

        filechooser.file_set.connect (() => {
            File f = filechooser.get_file ();
            f.load_contents_async.begin (null, (obj, res) => {
                uint8[] contents;
                try {
                    f.load_contents_async.end (res, out contents, null);
                    srcview.buffer.text = (string) contents;

                    vala_stuff (f.get_path ());
                } catch (Error e) {
                    error (e.message);
                }
            });
        });
    }
}

public class App : Gtk.Application {
    public App () {
        Object (application_id: "me.iofel.vala_editor",
                flags: ApplicationFlags.FLAGS_NONE);
    }

    public override void activate () {
        var win = new MainWindow (this);
        win.show_all ();
    }
}

int main (string[] args) {
    return new App ().run (args);
}
