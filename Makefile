VALAFLAGS = --pkg gtk+-3.0 --pkg gtksourceview-3.0 --pkg libvala-0.32 -g

editor: editor.vala
	valac $(VALAFLAGS) editor.vala
