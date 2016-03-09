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
                string etag;
                try {
                    f.load_contents_async.end (res, out contents, out etag);
                    src.buffer.text = (string) contents;
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
