class Reporter : Vala.Report {
    Gtk.ListStore store;

    public Reporter (Gtk.ListStore store) {
        this.store = store;
    }

    public override void depr (Vala.SourceReference? source, string message) {
        store.insert_with_values (null, -1,
            0, "dialog-warning",
            1, @"Deprecated: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++warnings;
    }
    public override void err (Vala.SourceReference? source, string message) {
        store.insert_with_values (null, -1,
            0, "dialog-error",
            1, @"Error: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++errors;
    }
    public override void note (Vala.SourceReference? source, string message) {
        store.insert_with_values (null, -1,
            0, "text-x-generic",
            1, @"Note: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++warnings;
    }
    public override void warn (Vala.SourceReference? source, string message) {
        store.insert_with_values (null, -1,
            0, "dialog-warning",
            1, @"Warning: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++warnings;
    }
}

void vala_stuff (string filename, Gtk.ListStore ts) {
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
    ctx.report = new Reporter (ts);
    ctx.add_external_package ("glib-2.0");
    ctx.add_external_package ("gobject-2.0");
    ctx.add_external_package ("gtk+-3.0");
    ctx.add_external_package ("gtksourceview-3.0");
    ctx.add_external_package ("libvala-0.30");
    /**
     * Vala expects you to handle unknown namespace/missing package errors via Report
     * If you don't quit in case of errors, you will have NULL variable types and CRITICALs
     */
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
    [GtkChild] Gtk.TreeView error_list;
    [GtkChild] Gtk.ListStore errorstore;

    public MainWindow (Gtk.Application a) {
        Object (application: a);
        set_default_size (800, 600);

        ((Gtk.SourceBuffer) srcview.buffer).language = Gtk.SourceLanguageManager.get_default ().get_language ("vala");

        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("", new Gtk.CellRendererPixbuf (), "icon-name", 0));
        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("Message", new Gtk.CellRendererText (), "text", 1));
        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("Line", new Gtk.CellRendererText (), "text", 2));
        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("Column", new Gtk.CellRendererText (), "text", 3));

        filechooser.file_set.connect (() => {
            File f = filechooser.get_file ();
            f.load_contents_async.begin (null, (obj, res) => {
                uint8[] contents;
                try {
                    f.load_contents_async.end (res, out contents, null);
                    srcview.buffer.text = (string) contents;

                    errorstore.clear ();
                    vala_stuff (f.get_path (), errorstore);
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
