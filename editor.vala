class SourceError {
    public Vala.SourceReference? loc;
    public string message;

    public SourceError(Vala.SourceReference? loc, string message) {
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
            2, source == null ? -1 : source.begin.line,
            3, source == null ? -1 : source.begin.column);
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
    ctx.report = new Reporter (errors);
    ctx.set_target_glib_version ("2.56");
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

        if (err.loc != null) {
            Gtk.TextIter begin;
            Gtk.TextIter end;
            source.get_iter_at_line_offset (out begin, err.loc.begin.line-1, err.loc.begin.column-1);
            source.get_iter_at_line_offset (out end, err.loc.end.line-1, err.loc.end.column);
            source.apply_tag (tag, begin, end);
        }
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

    Gtk.SourceBuffer srcbuffer;

    public MainWindow (Gtk.Application a) {
        Object (application: a);
        set_default_size (800, 600);

        srcview.buffer = srcbuffer = new Gtk.SourceBuffer (null);

        srcbuffer.language = Gtk.SourceLanguageManager.get_default ().get_language ("vala");
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

            if (line == -1 || column == -1)
                return;

            Gtk.TextIter target;
            srcbuffer.get_iter_at_line_offset (out target, line - 1, column - 1);
            srcbuffer.select_range (target, target);
            srcview.scroll_to_iter (target, 0.1, false, 0, 0);

            srcview.grab_focus ();
        });

        errorstore.set_sort_column_id (2, Gtk.SortType.ASCENDING);

        symboltree.model = new Gtk.TreeStore (2, typeof (Gdk.Pixbuf), typeof (string));
        symboltree.insert_column_with_attributes (-1, null, new Gtk.CellRendererPixbuf (), "pixbuf", 0);
        symboltree.insert_column_with_attributes (-1, null, new Gtk.CellRendererText (), "text", 1);

        filechooser.file_set.connect (() => load_file.begin (filechooser.get_file ()));
    }

    public async void load_file (File file) {
        errorstore.clear ();
        ((Gtk.TreeStore) symboltree.model).clear ();

        var gsvf = new Gtk.SourceFile ();
        gsvf.set_location (file);
        yield new Gtk.SourceFileLoader (srcbuffer, gsvf).load_async (Priority.DEFAULT, null, (cur, total) => {});

        vala_stuff (file.get_path (), srcbuffer, errorstore, (Gtk.TreeStore) symboltree.model, packages_entry.text.split(" "));
    }
}

public class App : Gtk.Application {
    public App () {
        Object (application_id: "me.iofel.vala_editor",
                flags: ApplicationFlags.HANDLES_OPEN);
    }

    public override void open (File[] files, string hint) {
        if (files.length > 1) {
           warning ("can only pass 1 file");
        }

        var win = new MainWindow (this);
        win.show_all ();
        win.load_file.begin (files[0]);
    }

    public override void activate () {
        var win = new MainWindow (this);
        win.show_all ();
    }
}

int main (string[] args) {
    return new App ().run (args);
}
