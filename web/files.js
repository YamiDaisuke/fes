export async function saveFileToDevice(fileName, bytes) {
  const file = new File([bytes], fileName, { type: "application/zip" });
  // In a Home Screen app <a download> opens an "Open in…" screen with no way back (WebKit bug 290847).
  if (matchMedia("(display-mode: standalone)").matches && navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file] });
    } catch (error) {
      if (error.name === "AbortError") return false;
      throw error;
    }
    return true;
  }
  const link = document.createElement("a");
  link.href = URL.createObjectURL(file);
  link.download = fileName;
  link.click();
  setTimeout(() => URL.revokeObjectURL(link.href), 60_000);
  return true;
}
