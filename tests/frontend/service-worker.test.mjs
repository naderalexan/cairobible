import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

test("the app shell serves the logo from cache when offline", async () => {
  const handlers = {};
  const cachedLogo = new Response("logo");
  const context = {
    self: {
      location: { origin: "https://bible.example" },
      addEventListener(type, handler) { handlers[type] = handler; },
    },
    URL,
    caches: { open: async () => ({ match: async () => cachedLogo }) },
    fetch: async () => { throw new Error("offline"); },
  };
  vm.runInNewContext(await readFile(new URL("../../public/sw.js", import.meta.url), "utf8"), context);

  let response;
  handlers.fetch({
    request: new Request("https://bible.example/icons/cairo-bible-mark.png"),
    respondWith(value) { response = value; },
  });
  assert.equal(await response, cachedLogo);
});
