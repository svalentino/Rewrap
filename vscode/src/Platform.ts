/** Host-platform abstractions. The default implementations here are the
 *  safe no-op fallbacks used by the web bundle. The desktop entry
 *  (`Extension.node.ts`) overwrites these with real Node implementations
 *  before any consumer is actually invoked.
 *
 *  Consumers MUST read fields lazily (e.g. `path => platform.readFile(path)`)
 *  rather than capturing them at module-load time, because ESM import
 *  hoisting causes consumer modules to evaluate before the entry file's
 *  top-level statements run. */
type ReadFile = (path: string) => string

export const platform: {readFile: ReadFile} = {
  readFile: () => "",
}
