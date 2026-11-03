async function cartsDirectory() {
  const root = await navigator.storage.getDirectory();
  return root.getDirectoryHandle("carts", { create: true });
}

export async function listCartFolders() {
  const folders = [];
  for await (const [name, handle] of (await cartsDirectory()).entries()) {
    if (handle.kind === "directory") folders.push(name);
  }
  return folders;
}

export async function readCartFile(folder, name) {
  let file;
  try {
    const folderHandle = await (await cartsDirectory()).getDirectoryHandle(folder);
    file = await (await folderHandle.getFileHandle(name)).getFile();
  } catch (error) {
    if (error.name === "NotFoundError") return null;
    throw error;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(await file.arrayBuffer());
}

export async function writeCartFile(folder, name, text) {
  const folderHandle = await (await cartsDirectory()).getDirectoryHandle(folder, { create: true });
  const writable = await (await folderHandle.getFileHandle(name, { create: true })).createWritable();
  await writable.write(text);
  await writable.close();
}

export async function requestPersistentStorage() {
  return navigator.storage.persist();
}
