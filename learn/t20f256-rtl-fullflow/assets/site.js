/* t20f256-rtl-fullflow 教程站点 —— 主题切换 + 复制按钮 + 进度记忆 */
(function () {
  var KEY = "t20f256-rtl-fullflow-progress";
  var THEME_KEY = "t20f256-theme";

  // 0. 主题：默认跟随系统（head 内联脚本已设 data-theme），手动切换后记忆选择
  var root = document.documentElement;
  function storedTheme() {
    try { return localStorage.getItem(THEME_KEY); } catch (e) { return null; }
  }
  if (!root.getAttribute("data-theme")) {
    root.setAttribute("data-theme", storedTheme() ||
      (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));
  }
  var toggle = document.createElement("button");
  toggle.type = "button";
  toggle.className = "theme-toggle";
  function syncToggle() {
    toggle.textContent = root.getAttribute("data-theme") === "dark" ? "☀ 亮色模式" : "🌙 暗色模式";
  }
  toggle.addEventListener("click", function () {
    var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try { localStorage.setItem(THEME_KEY, next); } catch (e) {}
    syncToggle();
  });
  syncToggle();
  var note = document.querySelector(".sidebar .progress-note");
  if (note) note.after(toggle);

  // 0b. 阅读进度重置：清空记录、去掉导航 ✓、首页进度条归零
  var resetBtn = document.createElement("button");
  resetBtn.type = "button";
  resetBtn.className = "theme-toggle";
  resetBtn.textContent = "↺ 重置阅读进度";
  resetBtn.addEventListener("click", function () {
    if (!window.confirm("确定清空这台浏览器里的阅读进度？")) return;
    try { localStorage.removeItem(KEY); } catch (e) {}
    document.querySelectorAll(".sidebar nav a.done").forEach(function (a) {
      a.classList.remove("done");
    });
    var bar = document.getElementById("progress-fill");
    var label = document.getElementById("progress-label");
    if (bar) bar.style.width = "0%";
    if (label) label.textContent = "已读 0 / 12 章";
  });
  if (note) toggle.after(resetBtn);
  // 系统偏好变化时，仅在用户未手动选择过的情况下跟随
  var mq = window.matchMedia("(prefers-color-scheme: dark)");
  function onScheme(e) {
    if (storedTheme()) return;
    root.setAttribute("data-theme", e.matches ? "dark" : "light");
    syncToggle();
  }
  if (mq.addEventListener) mq.addEventListener("change", onScheme);
  else if (mq.addListener) mq.addListener(onScheme);

  function readProgress() {
    try { return JSON.parse(localStorage.getItem(KEY) || "[]"); }
    catch (e) { return []; }
  }
  function writeProgress(list) {
    try { localStorage.setItem(KEY, JSON.stringify(list)); } catch (e) {}
  }

  // 1. 记录当前章（目录页不计入章进度）
  var body = document.body;
  var ch = body.getAttribute("data-ch");
  if (ch && ch !== "index") {
    var p = readProgress();
    if (p.indexOf(ch) < 0) { p.push(ch); writeProgress(p); }
  }

  // 2. 侧边导航：标记当前章 + 已完成章
  var done = readProgress();
  document.querySelectorAll(".sidebar nav a").forEach(function (a) {
    var target = a.getAttribute("data-ch");
    if (target && done.indexOf(target) >= 0) a.classList.add("done");
    if (ch && target === ch) a.classList.add("active");
  });

  // 3. 首页进度条
  var bar = document.getElementById("progress-fill");
  var label = document.getElementById("progress-label");
  if (bar) {
    var total = 12; // 01..12
    bar.style.width = Math.round(done.length / total * 100) + "%";
    if (label) label.textContent = "已读 " + done.length + " / " + total + " 章";
  }

  // 4. 复制按钮：data-copy 属性内容进剪贴板；无 data-copy 则取相邻 pre 文本
  document.querySelectorAll(".copy-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");
      if (!text) {
        var block = btn.closest(".codeblock") || btn.closest(".say");
        var pre = block && block.querySelector("pre");
        text = pre ? pre.innerText : "";
      }
      function flash() {
        btn.classList.add("copied");
        var old = btn.textContent;
        btn.textContent = "已复制";
        setTimeout(function () { btn.textContent = old; btn.classList.remove("copied"); }, 1400);
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(flash, function () { legacy(text); flash(); });
      } else { legacy(text); flash(); }
    });
  });
  function legacy(text) {
    var ta = document.createElement("textarea");
    ta.value = text; document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta);
  }
})();
