VALAFLAGS = \
	--pkg gtk+-3.0 \
	--pkg gtksourceview-3.0 \
	--pkg libvala-0.32 \
	-g \
	--target-glib 2.44 \
	--gresources data/resources.xml

editor: editor.vala resources.c
	valac $(VALAFLAGS) editor.vala resources.c

resources.c: data/resources.xml
	glib-compile-resources --sourcedir data --generate-source $< --target $@
