/** Web (browser / web-worker) entry point. The default `platform.readFile`
 *  from `./Platform` is left in place, which causes custom language-
 *  configuration markers to be unavailable in the web host. Restoring that
 *  capability for the web requires reading files via `vscode.workspace.fs`
 *  asynchronously and is intentionally out of scope here.
 *
 *  VS Code's web host loads this file via the `browser` field in
 *  package.json. */
export {activate, getCoreSettings, getEditorSettings} from './Extension'
