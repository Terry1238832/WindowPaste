"use strict";
(() => {
  const finder = document.querySelector(".finder");
  if (!finder) return;

  const action = document.querySelector("#demo-action");
  const reset = document.querySelector(".demo-reset");
  const status = document.querySelector("#demo-status-text");
  const count = document.querySelector("#finder-count");
  const label = action.querySelector(".action-label");
  const key = action.querySelector(".action-key");
  const placeholder = document.querySelector("#composer-placeholder");
  const composerShot = document.querySelector(".composer-shot");
  const sentImage = document.querySelector(".sent-image");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let phase = "ready";
  let pending;

  const states = {
    ready: ["光标已在聊天框，准备截取 LetsView。", "目标 · LetsView", "截取并粘贴", "⌘ `", "⌘"],
    pasted: ["截图已粘贴到输入框。", "剪贴板 · 已复制", "自动回车发送", "⏎", "⎘"],
    sent: ["已发送。光标仍在聊天框。", "微信 · 已发送", "再试一次", "↺", "✓"]
  };

  function show(next) {
    phase = next;
    finder.dataset.phase = next;
    const [message, counter, text, shortcut, symbol] = states[next];
    status.textContent = message;
    count.textContent = counter;
    label.textContent = text;
    key.textContent = shortcut;
    finder.querySelector(".status-symbol").textContent = symbol;
    action.disabled = false;
    placeholder.hidden = next !== "ready";
    composerShot.hidden = next !== "pasted";
    sentImage.hidden = next !== "sent";
    document.querySelector(".composer").hidden = next === "sent";
    document.querySelectorAll("[data-step]").forEach((step) => {
      step.classList.toggle("active", step.dataset.step === next);
    });
  }

  action.addEventListener("click", () => {
    if (phase === "ready") show("pasted");
    else if (phase === "pasted") {
      phase = "sending";
      finder.dataset.phase = "sending";
      action.disabled = true;
      composerShot.hidden = true;
      sentImage.hidden = false;
      status.textContent = "正在发送…";
      pending = window.setTimeout(() => show("sent"), reducedMotion.matches ? 0 : 380);
    } else if (phase === "sent") show("ready");
  });

  reset.addEventListener("click", () => {
    window.clearTimeout(pending);
    show("ready");
  });

  document.querySelectorAll(".window-card").forEach((card) => {
    card.addEventListener("click", () => {
      document.querySelectorAll(".window-card").forEach((item) => {
        const selected = item === card;
        item.classList.toggle("selected", selected);
        const meta = item.querySelector("small");
        if (meta) meta.textContent = selected ? (item.dataset.pick === "letsview" ? "1249×853 · 当前桌面" : "当前桌面") : "未选中";
      });
      const name = card.dataset.pick === "letsview" ? "LetsView" : "微信";
      document.querySelector("#dim-preview-status").textContent = `已选择 ${name}。按下 ⌘\` 会截这一扇窗口。`;
    });
  });

  document.querySelectorAll('a[href="#faq-windows"]').forEach((link) => {
    link.addEventListener("click", () => {
      document.querySelector("#faq-windows").open = true;
    });
  });
  if (window.location.hash === "#faq-windows") document.querySelector("#faq-windows").open = true;

  if ("IntersectionObserver" in window && !reducedMotion.matches) {
    document.documentElement.classList.add("motion-ready");
    const observer = new IntersectionObserver((entries) => entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    }), { threshold: 0.08 });
    document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));
  }
})();
