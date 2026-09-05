# Front-end dependency policy

Odontome uses the following pinned, commercially usable open-source packages:

| Package | Version | License | How it is used |
| --- | --- | --- | --- |
| Tabler | 1.4.0 | MIT | `@tabler/core` supplies the theme CSS, JavaScript, vendor styles, and official theme switcher. |
| FullCalendar Standard Bundle | 6.1.18 | MIT | Loaded from Tabler's `dist/libs/fullcalendar` integration. It contains only the standard plugins. |
| Bootstrap | 5.3.7 | MIT | Bundled and exported by Tabler; also declared as its package dependency. |
| Popper | 2.11.8 | MIT | Transitive dependency of Tabler. |

`theme.js` loads Tabler's upstream theme switcher before selecting its official
`neutral` base palette. The `tabler-themes` stylesheet supplies those colors;
light/dark selection and persistence remain owned by Tabler. The main bundle
initializes help popovers and tooltips on DOM ready because it loads in the head.

The MIT licenses allow commercial use, modification, and distribution provided
their copyright and permission notices are retained. The distributed Tabler
and FullCalendar assets include their upstream license banners. Package license
files remain available in `node_modules` after `yarn install`.

FullCalendar Premium / Scheduler plugins are deliberately not included. Those
plugins have separate commercial licensing terms and must not be added without
a new license review.

Primary references:

- [Tabler repository and MIT license](https://github.com/tabler/tabler)
- [FullCalendar licensing](https://fullcalendar.io/license)
- [FullCalendar Standard Bundle documentation](https://fullcalendar.io/docs/initialize-globals)

When upgrading, pin the exact `@tabler/core` version in `package.json`, confirm
the bundled FullCalendar version in
`node_modules/@tabler/core/dist/libs/fullcalendar/package.json`, and rerun the
full Rails suite plus the browser checks above.

## Deployment

Tabler and FullCalendar assets come from `node_modules`, not vendored files.
Install dependencies with `yarn install --frozen-lockfile` before running Rails
asset precompilation. `package.json` selects Node 24 and Yarn 1.22.22; CI uses
the same versions and lockfile, then checks production asset precompilation.

On Heroku, the `heroku/nodejs` buildpack must run before `heroku/ruby` so those
files exist when Sprockets compiles assets. `app.json` declares that order for
new apps; it does not update existing apps. For an existing app with only the
Ruby buildpack, add Node first:

```sh
heroku buildpacks:add --index 1 heroku/nodejs --app YOUR_APP_NAME
heroku buildpacks --app YOUR_APP_NAME
```

The resulting order must be Node.js first, Ruby last. This setting takes effect
on the next deployment; changing buildpacks does not deploy the app.
