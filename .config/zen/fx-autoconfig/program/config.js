// skip 1st line
try {

  let UChrm = Cc['@mozilla.org/file/directory_service;1'].getService(Ci.nsIProperties).get('UChrm', Ci.nsIFile);
  let ProfD = Cc['@mozilla.org/file/directory_service;1'].getService(Ci.nsIProperties).get('ProfD', Ci.nsIFile);

  function logErr(text) {
    try {
      let f = ProfD.clone();
      f.append('zen-autoconfig-err.log');
      let s = Cc['@mozilla.org/network/file-output-stream;1'].createInstance(Ci.nsIFileOutputStream);
      s.init(f, 0x02 | 0x08 | 0x20, 0o644, 0);
      s.write(text, text.length);
      s.close();
    } catch (e) {}
  }

  let cmanifest = UChrm.clone();
  cmanifest.append('utils');
  cmanifest.append('chrome.manifest');

  if (cmanifest.exists()) {
    try {
      Components.manager.QueryInterface(Ci.nsIComponentRegistrar).autoRegister(cmanifest);
    } catch (e) {
      logErr("autoRegister failed: " + e + "\nmanifest=" + cmanifest.path + "\n");
    }
    try {
      ChromeUtils.importESModule('chrome://userchromejs/content/boot.sys.mjs');
    } catch (e) {
      logErr("importESModule failed: " + e + "\nUChrm=" + UChrm.path + "\n");
    }
  } else {
    logErr("manifest missing: " + cmanifest.path + "\nUChrm=" + UChrm.path + "\n");
  }
} catch (ex) {
  try {
    let ProfD = Cc['@mozilla.org/file/directory_service;1'].getService(Ci.nsIProperties).get('ProfD', Ci.nsIFile);
    let f = ProfD.clone();
    f.append('zen-autoconfig-err.log');
    let s = Cc['@mozilla.org/network/file-output-stream;1'].createInstance(Ci.nsIFileOutputStream);
    s.init(f, 0x02 | 0x08 | 0x20, 0o644, 0);
    s.write("outer: " + ex + "\n", 14 + ("" + ex).length);
    s.close();
  } catch (e) {}
}
