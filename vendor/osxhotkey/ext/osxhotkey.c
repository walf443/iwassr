
#include <Carbon/Carbon.h>
#include <ruby.h>

struct rhk {
	EventHotKeyRef hotkeyref;
};

static VALUE
rhk_alloc(VALUE klass) {
	struct rhk* ptr = ALLOC(struct rhk);

	return Data_Wrap_Struct(klass, 0, -1, ptr);
}

/*
 * Create Hotkey instance with keyCode and modifiers.
 */
static VALUE
rhk_initialize(VALUE self, VALUE keyCode, VALUE modifiers) {
	rb_ivar_set(self, rb_intern("@keyCode"), keyCode);
	rb_ivar_set(self, rb_intern("@modifiers"), modifiers);

	return Qnil;
}

/*
 * Register self as OSX hotkey.
 */
static VALUE
rhk_register(VALUE self) {
	static UInt32 _id = 0;
	VALUE modifiers, keyCode;

	keyCode   = rb_ivar_get(self, rb_intern("@keyCode"));
	modifiers = rb_ivar_get(self, rb_intern("@modifiers"));

	UInt32 modifier = NUM2INT(modifiers);

	EventHotKeyID keyId;
	keyId.signature = 'HtKe';
	keyId.id = _id++;

	EventHotKeyRef hotKeyRef;
	OSStatus status = RegisterEventHotKey(
			NUM2INT(keyCode),
			modifier,
			keyId,
			GetApplicationEventTarget(),
			0,
			&hotKeyRef
	);

	if (status != noErr) rb_raise(rb_eStandardError, "RegisterEventHotKey returned Error status");

	struct rhk* ptr;
	Data_Get_Struct(self, struct rhk, ptr);
	ptr->hotkeyref = hotKeyRef;

	return INT2NUM((unsigned int)hotKeyRef);
}

/*
 * Unregister self from OSX hotkeys.
 */
static VALUE
rhk_unregister(VALUE self) {
	struct rhk* ptr;
	Data_Get_Struct(self, struct rhk, ptr);
	UnregisterEventHotKey(ptr->hotkeyref);
	return Qtrue;
}

void
Init_osxhotkey () {
	VALUE HotKey;
	VALUE module;

	rb_eval_string("require 'osx/cocoa'");
	module = rb_eval_string("OSX");

	HotKey = rb_define_class_under(module, "HotKey", rb_cObject);
	rb_define_const(HotKey, "SHIFT", INT2NUM(shiftKey));
	rb_define_const(HotKey, "CONTROL", INT2NUM(controlKey));
	rb_define_const(HotKey, "COMMAND", INT2NUM(cmdKey));
	rb_define_const(HotKey, "OPTION", INT2NUM(optionKey));

	rb_define_alloc_func(HotKey, rhk_alloc);
	rb_define_private_method(HotKey, "initialize", rhk_initialize, 2);
	rb_define_method(HotKey, "register", rhk_register, 0);
	rb_define_method(HotKey, "unregister", rhk_unregister, 0);
}


