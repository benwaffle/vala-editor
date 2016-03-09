class Reporter : Vala.Report {
    public override void depr (Vala.SourceReference? source, string message) {
        GLib.message (@"Deprecated: $message");
    }
    public override void err (Vala.SourceReference? source, string message) {
        GLib.message (@"Error: $message");
    }
    public override void note (Vala.SourceReference? source, string message) {
        GLib.message (@"Note: $message");
    }
    public override void warn (Vala.SourceReference? source, string message) {
        GLib.message (@"Warning: $message");
    }
}

void vala_stuff (string filename) {
    var ctx = new Vala.CodeContext ();
    Vala.CodeContext.push (ctx);
    ctx.add_package ("glib-2.0");
    ctx.add_package ("gobject-2.0");
    ctx.add_package ("gtk+-3.0");
    ctx.add_package ("gtksourceview-3.0");
    ctx.profile = Vala.Profile.GOBJECT;
    ctx.add_source_filename (filename, true, false);
    ctx.report = new Reporter ();

    var parser = new Vala.Parser ();
    parser.parse (ctx);

    ctx.check ();
    Vala.CodeContext.pop ();
}

public class MainWindow : Gtk.ApplicationWindow {
    public MainWindow (Gtk.Application a) {
        Object (application: a);
        set_default_size (800, 600);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        var srcbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        add (box);
        box.pack_end (srcbox);

        var fc = new Gtk.FileChooserButton ("choose a file", Gtk.FileChooserAction.OPEN);
        var filt = new Gtk.FileFilter ();
        filt.add_pattern ("*.vala");
        fc.add_filter (filt);
        box.pack_start (fc, false, false);

        var src_scroll = new Gtk.ScrolledWindow (null, null);
        var src = new Gtk.SourceView ();
        src_scroll.add (src);

        src.monospace = true;
        src.auto_indent = true;
        src.highlight_current_line = true;
        src.indent_on_tab = true;
        src.show_line_numbers = true;
        src.smart_backspace = true;
        ((Gtk.SourceBuffer) src.buffer).language = Gtk.SourceLanguageManager.get_default ().get_language ("vala");

        var map = new Gtk.SourceMap ();
        map.view = src;
        srcbox.pack_start (src_scroll);
        srcbox.pack_end (map, false, false);
        srcbox.pack_end (new Gtk.Separator (Gtk.Orientation.VERTICAL), false, false);

        fc.file_set.connect (() => {
            File f = fc.get_file ();
            f.load_contents_async.begin (null, (obj, res) => {
                uint8[] contents;
                try {
                    f.load_contents_async.end (res, out contents, null);
                    src.buffer.text = (string) contents;

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
