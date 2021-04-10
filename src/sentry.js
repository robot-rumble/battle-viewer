import * as Sentry from '@sentry/browser'
import { Integrations } from '@sentry/tracing'

// Sentry fails silently if DSN isn't provided
// so this should work for dev mode
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  integrations: [new Integrations.BrowserTracing()],

  // Set tracesSampleRate to 1.0 to capture 100%
  // of transactions for performance monitoring.
  // We recommend adjusting this value in production
  tracesSampleRate: 1.0,
})

export function captureMessage(message, data) {
  // Sentry doesn't provide the option of seeing the full message if it's long
  // and Elm decode errors that log the entire data structure are very long
  // and have the useful bit at the very end, which is truncated by Sentry
  const truncatedData = data.length < 2000 ? data : data.slice(0, 1000) + '\n...TRUNCATED...\n' + data.slice(-1000)

  Sentry.captureEvent({
    message,
    breadcrumbs: [{
      message: truncatedData,
    }],
  })
}
