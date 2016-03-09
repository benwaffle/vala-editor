VALAFLAGS = \
	--pkg gtk+-3.0 \
	--pkg gtksourceview-3.0 \
	--pkg libvala-0.30 \
	-g \
	--target-glib 2.44 \
	--gresources resources.xml

editor: editor.vala resources.c
	valac $(VALAFLAGS) editor.vala resources.c

resources.c: resources.xml
	glib-compile-resources --generate-source $< --target $@
