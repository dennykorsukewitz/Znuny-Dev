# Manual changes tracked (Cursor)

## Dashboard: status progress panel (multiple concurrent operations)

- **Files:** [`dev/dashboard/public/index.html`](dev/dashboard/public/index.html), [`dev/dashboard/public/app.css`](dev/dashboard/public/app.css), [`dev/dashboard/public/app.js`](dev/dashboard/public/app.js)
- **Behavior:** **`zd` commands:** `.instance-zd-progress` in **cards** is inserted in `.instance-header` **between** `.instance-name` and `.instance-status` (`insertBefore`); in **table** view it is inserted at the top of `td.cell-actions` before `.instance-actions`. **`loadStatus` (refresh / initial):** toast `#global-progress-panel` unless `{ showProgress: false }` after `/api/zd`.
