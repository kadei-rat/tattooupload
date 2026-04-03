"use strict";
(() => {
  // ts/app.ts
  document.addEventListener("DOMContentLoaded", () => {
    initErrorBanner();
    initTelegramLogin();
  });
  function initTelegramLogin() {
    const container = document.getElementById("telegram-login");
    if (!container) return;
    const botName = container.getAttribute("data-telegram-login");
    if (!botName) return;
    const script = document.createElement("script");
    script.src = "https://telegram.org/js/telegram-widget.js?22";
    script.async = true;
    script.setAttribute("data-telegram-login", botName);
    script.setAttribute("data-size", container.getAttribute("data-size") || "medium");
    script.setAttribute("data-radius", container.getAttribute("data-radius") || "5");
    script.setAttribute("data-request-access", container.getAttribute("data-request-access") || "write");
    script.setAttribute("data-onauth", "onTelegramAuth(user)");
    container.appendChild(script);
  }
  function initErrorBanner() {
    const params = new URLSearchParams(window.location.search);
    const error = params.get("error");
    if (error) {
      window.showErrorBanner(error);
    }
  }
  window.showErrorBanner = function(message) {
    const existing = document.getElementById("error-banner");
    if (existing) existing.remove();
    const banner = document.createElement("div");
    banner.className = "error-banner";
    banner.id = "error-banner";
    const span = document.createElement("span");
    span.textContent = message;
    const dismiss = document.createElement("button");
    dismiss.className = "error-banner-dismiss";
    dismiss.type = "button";
    dismiss.textContent = "\xD7";
    dismiss.onclick = () => banner.remove();
    banner.appendChild(span);
    banner.appendChild(dismiss);
    const main = document.querySelector("main") || document.body;
    main.insertBefore(banner, main.firstChild);
  };
  window.dismissErrorBanner = function() {
    const banner = document.getElementById("error-banner");
    if (banner) banner.remove();
    const url = new URL(window.location.href);
    url.searchParams.delete("error");
    window.history.replaceState({}, "", url.toString());
  };
  window.onTelegramAuth = function(user) {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = "/login";
    for (const [key, value] of Object.entries(user)) {
      if (value !== void 0) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = key;
        input.value = String(value);
        form.appendChild(input);
      }
    }
    const container = document.getElementById("telegram-login");
    const returnUrl = container?.getAttribute("data-return-url") || "/";
    const returnInput = document.createElement("input");
    returnInput.type = "hidden";
    returnInput.name = "return_url";
    returnInput.value = returnUrl;
    form.appendChild(returnInput);
    document.body.appendChild(form);
    form.submit();
  };
})();
