package gml;
import electron.FileSystem;
import js.html.Element;
import ace.AceWrap;
import gmx.*;
import Main.document;
import haxe.io.Path;
import yy.YyBase;
import yy.YyObject;
using tools.HtmlTools;

/**
 * ...
 * @author YellowAfterlife
 */
class GmlFile {
	public static var next:GmlFile = null;
	public static var current:GmlFile = null;
	//
	public var name:String;
	public var path:String;
	public var code:String;
	public var kind:GmlFileKind = Normal;
	public var session:AceSession;
	public var tabEl:Element;
	public var changed(get, set):Bool;
	private var __changed:Bool = false;
	private inline function get_changed() {
		return __changed;
	}
	private function set_changed(z:Bool) {
		if (__changed != z) {
			__changed = z;
			if (z) {
				tabEl.classList.add("chrome-tab-changed");
			} else {
				tabEl.classList.remove("chrome-tab-changed");
			}
		}
		return z;
	}
	//
	public function new(name:String, path:String, kind:GmlFileKind, ?data:Dynamic) {
		this.name = name;
		this.path = path;
		this.kind = kind;
		load(data);
		session = new AceSession(code, "ace/mode/gml");
		session.setUndoManager(new AceUndoManager());
	}
	//
	public static function open(name:String, path:String) {
		// see if there's an existing tab for this:
		for (tabEl in ui.ChromeTabs.element.querySelectorEls('.chrome-tab')) {
			var gmlFile:GmlFile = untyped tabEl.gmlFile;
			if (gmlFile != null && gmlFile.path == path) {
				tabEl.click();
				return;
			}
		}
		// determine what to do with the file:
		var kind:GmlFileKind;
		var ext = Path.extension(path).toLowerCase();
		var data:Dynamic = null;
		switch (ext) {
			case "gml": kind = Normal;
			case "gmx": {
				ext = Path.extension(Path.withoutExtension(path)).toLowerCase();
				kind = switch (ext) {
					case "object": GmxObjectEvents;
					case "project": GmxProjectMacros;
					case "config": GmxConfigMacros;
					default: Extern;
				}
			};
			case "yy": {
				var json:YyBase = FileSystem.readJsonFileSync(path);
				switch (json.modelName) {
					case "GMObject": {
						data = json;
						kind = YyObjectEvents;
					}
					case "GMScript": {
						path = Path.withoutExtension(path) + ".gml";
						kind = Normal;
					}
					default: kind = Extern;
				};
			};
			default: kind = Extern;
		}
		//
		if (kind != Extern) {
			// addTab doesn't return the new tab so we bind it up in the "active tab change" event:
			GmlFile.next = new GmlFile(name, path, kind, data);
			ui.ChromeTabs.addTab(name);
		} else {
			electron.Shell.openItem(path);
		}
	}
	//
	public function load(?data:Dynamic) {
		var src:String = data != null ? null : FileSystem.readTextFileSync(path);
		var gmx:SfGmx, out:String, errors:String;
		switch (kind) {
			case Normal, Extern: code = src;
			case GmxObjectEvents: {
				gmx = SfGmx.parse(src);
				out = GmxObject.getCode(gmx);
				if (out == null) {
					code = GmxObject.errorText;
				} else code = out;
			};
			case GmxProjectMacros, GmxConfigMacros: {
				gmx = SfGmx.parse(src);
				code = GmxProject.getMacroCode(gmx, kind == GmxConfigMacros);
			};
			case YyObjectEvents: {
				var obj:yy.YyObject = data;
				code = obj.getCode(path);
			};
		}
	}
	//
	public function save() {
		var val = session.getValue();
		//
		var out:String, src:String, gmx:SfGmx;
		switch (kind) {
			case Normal, Extern: out = val;
			case GmxObjectEvents: {
				gmx = FileSystem.readGmxFileSync(path);
				if (!GmxObject.updateCode(gmx, val)) {
					Main.window.alert("Can't update GMX:\n" + GmxObject.errorText);
					return;
				}
				out = gmx.toGmxString();
			};
			case GmxProjectMacros, GmxConfigMacros: {
				gmx = FileSystem.readGmxFileSync(path);
				GmxProject.setMacroCode(gmx, val, kind == GmxConfigMacros);
				out = gmx.toGmxString();
			};
			case YyObjectEvents: {
				var obj:YyObject = FileSystem.readJsonFileSync(path);
				if (!obj.setCode(path, val)) {
					Main.window.alert("Can't update YY:\n" + YyObject.errorText);
					return;
				}
				out = haxe.Json.stringify(obj, null, "    ");
			};
			default: {
				return;
			};
		}
		//
		//session.setValue(out);
		FileSystem.writeFileSync(path, out);
		changed = false;
		session.getUndoManager().markClean();
	}
}
@:fakeEnum(Int) enum GmlFileKind {
	Extern;
	Normal;
	GmxObjectEvents;
	GmxProjectMacros;
	GmxConfigMacros;
	YyObjectEvents;
}
