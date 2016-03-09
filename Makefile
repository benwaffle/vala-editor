VALAFLAGS = --pkg gtk+-3.0 --pkg gtksourceview-3.0 --pkg libvala-0.30 -g

editor: editor.vala
	valac $(VALAFLAGS) editor.vala
