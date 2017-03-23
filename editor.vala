class SourceError {
    public Vala.SourceReference loc;
    public string message;

    public SourceError(Vala.SourceReference loc, string message) {
        this.loc = loc;
        this.message = message;
    }
}

class Reporter : Vala.Report {
    public GenericArray<SourceError> errorlist = new GenericArray<SourceError> ();
    public GenericArray<SourceError> warnlist = new GenericArray<SourceError> ();
    Gtk.ListStore store;

    public Reporter (Gtk.ListStore store) {
        this.store = store;
    }

    public override void depr (Vala.SourceReference? source, string message) {
        warnlist.add (new SourceError (source, message));
        store.insert_with_values (null, -1,
            0, "dialog-warning",
            1, @"Deprecated: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++warnings;
    }
    public override void err (Vala.SourceReference? source, string message) {
        errorlist.add (new SourceError (source, message));
        store.insert_with_values (null, -1,
            0, "dialog-error",
            1, @"Error: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++errors;
    }
    public override void note (Vala.SourceReference? source, string message) {
        warnlist.add (new SourceError (source, message));
        store.insert_with_values (null, -1,
            0, "text-x-generic",
            1, @"Note: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++warnings;
    }
    public override void warn (Vala.SourceReference? source, string message) {
        warnlist.add (new SourceError (source, message));
        store.insert_with_values (null, -1,
            0, "dialog-warning",
            1, @"Warning: $message",
            2, source.begin.line,
            3, source.begin.column);
        ++warnings;
    }
}

Gdk.Pixbuf? type_image (string type) {
    try {
        if (type == "ValaClass")
            return new Gdk.Pixbuf.from_resource ("/me/iofel/vala-editor/class.svg");
        if (type == "ValaMethod")
            return new Gdk.Pixbuf.from_resource ("/me/iofel/vala-editor/method.svg");
        if (type == "ValaField")
            return new Gdk.Pixbuf.from_resource ("/me/iofel/vala-editor/field.svg");
        if (type == "ValaNamespace")
            return new Gdk.Pixbuf.from_resource ("/me/iofel/vala-editor/namespace.svg");
        if (type == "ValaCreationMethod")
            return new Gdk.Pixbuf.from_resource ("/me/iofel/vala-editor/constructor.svg");
    } catch (Error e) {
        warning (e.message);
    }
    return null;
}

void findsyms (Vala.Symbol top, Gtk.TreeStore tree, Gtk.TreeIter? parent = null) {
    if (top is Vala.Parameter)
        return;

    Gtk.TreeIter cur;
    tree.insert_with_values (out cur, parent, -1, 0, type_image (top.type_name), 1, top.name);
    Vala.Map<string, Vala.Symbol>? syms = top.scope.get_symbol_table ();
    if (syms != null)
        foreach (string s in syms.get_keys ())
            findsyms (syms[s], tree, cur);
}

void vala_stuff (string filename, Gtk.TextBuffer source, Gtk.ListStore errors, Gtk.TreeStore syms, string[] packages) {
    var ctx = new Vala.CodeContext ();
    Vala.CodeContext.push (ctx);

    ctx.profile = Vala.Profile.GOBJECT;
    for (int i = 2; i <= 34; i += 2) {
        ctx.add_define ("VALA_0_%d".printf (i));
    }
    ctx.target_glib_major = 2;
    ctx.target_glib_major = 44;
    for (int i = 16; i <= ctx.target_glib_major; i += 2) {
        ctx.add_define ("GLIB_2_%d".printf (i));
    }
    ctx.report = new Reporter (errors);
    ctx.add_external_package ("glib-2.0");
    ctx.add_external_package ("gobject-2.0");
    foreach (string pkg in packages)
        ctx.add_external_package (pkg);

    /**
     * Vala expects you to handle unknown namespace/missing package errors via Report
     * If you don't quit in case of errors, you will have NULL variable types and CRITICALs
     */

    print ("========== adding files ==============\n");

    ctx.add_source_filename (filename);
    print ("%d errors, %d warnings\n", ctx.report.get_errors (), ctx.report.get_warnings ());

    if (ctx.report.get_errors () == 0) {
        print ("========== parsing ==============\n");

        var parser = new Vala.Parser ();
        parser.parse (ctx);
        print ("%d errors, %d warnings\n", ctx.report.get_errors (), ctx.report.get_warnings ());

        if (ctx.report.get_errors () == 0) {
            print ("========== checking ==============\n");

            ctx.check ();
            print ("%d errors, %d warnings\n", ctx.report.get_errors (), ctx.report.get_warnings ());

            if (ctx.report.get_errors () == 0) {
                foreach (Vala.SourceFile file in ctx.get_source_files ())
                    if (file.filename.has_suffix (".vala")) {
                        Vala.List<Vala.CodeNode> nodes = file.get_nodes ();
                        foreach (Vala.CodeNode node in nodes)
                            if (node is Vala.Symbol)
                                findsyms ((Vala.Symbol) node, syms);
                    }
            }
        }
    }

    var report = ((Reporter) ctx.report);
    report.errorlist.foreach (err => {
        var tag = new Gtk.TextTag ();
        tag.set_data ("message", err.message);
        tag.underline = Pango.Underline.ERROR;
        source.tag_table.add (tag);

        Gtk.TextIter begin;
        Gtk.TextIter end;
        source.get_iter_at_line_offset (out begin, err.loc.begin.line-1, err.loc.begin.column-1);
        source.get_iter_at_line_offset (out end, err.loc.end.line-1, err.loc.end.column);
        source.apply_tag (tag, begin, end);
    });
    report.warnlist.foreach (err => {
        var tag = new Gtk.TextTag ();
        tag.set_data ("message", err.message);
        tag.underline_rgba = Gdk.RGBA () { red = 1, blue = 0, green = 1, alpha = 1};
        tag.underline = Pango.Underline.ERROR;
        source.tag_table.add (tag);

        Gtk.TextIter begin;
        Gtk.TextIter end;
        source.get_iter_at_line_offset (out begin, err.loc.begin.line-1, err.loc.begin.column-1);
        source.get_iter_at_line_offset (out end, err.loc.end.line-1, err.loc.end.column);
        source.apply_tag (tag, begin, end);
    });

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
        srcview.has_tooltip = true;
        srcview.query_tooltip.connect ((x, y, keyboard_tooltip, tooltip) => {
            int bx, by;
            srcview.window_to_buffer_coords (Gtk.TextWindowType.WIDGET, x, y, out bx, out by);
            Gtk.TextIter iter;
            srcview.get_iter_at_location (out iter, bx, by);
            var tags = iter.get_tags ();
            if (tags != null) {
                string? msg = tags.data.get_data ("message");
                if (msg != null) {
                    tooltip.set_text (msg);
                    return true;
                }
            }
            return false;
        });

        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("", new Gtk.CellRendererPixbuf (), "icon-name", 0));
        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("Message", new Gtk.CellRendererText (), "text", 1));
        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("Line", new Gtk.CellRendererText (), "text", 2));
        error_list.append_column (new Gtk.TreeViewColumn.with_attributes ("Column", new Gtk.CellRendererText (), "text", 3));

        error_list.row_activated.connect ((path, col) => {
            Gtk.TreeIter iter;
            errorstore.get_iter (out iter, path);
            int line, column;
            errorstore.get (iter,
                                  2, out line,
                                  3, out column,
                                  -1);

            Gtk.TextIter target;
            srcview.buffer.get_iter_at_line_offset (out target, line - 1, column - 1);
            srcview.buffer.select_range (target, target);
            srcview.scroll_to_iter (target, 0.1, false, 0, 0);

            srcview.grab_focus ();
        });

        symboltree.model = new Gtk.TreeStore (2, typeof (Gdk.Pixbuf), typeof (string));
        symboltree.insert_column_with_attributes (-1, null, new Gtk.CellRendererPixbuf (), "pixbuf", 0);
        symboltree.insert_column_with_attributes (-1, null, new Gtk.CellRendererText (), "text", 1);

        filechooser.file_set.connect (() => {
            File f = filechooser.get_file ();
            f.load_contents_async.begin (null, (obj, res) => {
                uint8[] contents;
                try {
                    f.load_contents_async.end (res, out contents, null);
                    srcview.buffer.tag_table.foreach (srcview.buffer.tag_table.remove);
                    srcview.buffer.text = (string) contents;

                    errorstore.clear ();
                    ((Gtk.TreeStore)symboltree.model).clear ();
                    vala_stuff (f.get_path (), srcview.buffer, errorstore, (Gtk.TreeStore) symboltree.model, packages_entry.text.split(" "));
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
