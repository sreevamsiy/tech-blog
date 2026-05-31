function setupImageLinks() {
  document.addEventListener("click", (event) => {
    const image = event.target.closest(".article-body img");

    if (!image) {
      return;
    }

    window.open(image.currentSrc || image.src, "_blank", "noopener,noreferrer");
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setupImageLinks);
} else {
  setupImageLinks();
}
