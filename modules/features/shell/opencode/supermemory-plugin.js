// V1-compatible loader shim for opencode-supermemory.
// OpenCode 1.x requires each `plugin` entry to default-export `{ server() }`,
// but opencode-supermemory@2.x only provides the named `SupermemoryPlugin`
// export from its root entry, so the bare package spec can never load
// (see "failed to load plugin ... must default export an object with server()").
// This re-exports it in the shape the loader accepts.
// dist/index.js is fully bundled (no external imports), so an absolute import
// keeps working regardless of resolver context. The package itself is
// installed via the declarative npm globals (modules/features/shell/npm).
import { SupermemoryPlugin } from "/home/parazeeknova/.npm-global/lib/node_modules/opencode-supermemory/dist/index.js";
export default { id: "supermemory", server: SupermemoryPlugin };
