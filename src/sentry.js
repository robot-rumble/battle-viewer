import * as Sentry from '@sentry/browser'
import { Integrations } from '@sentry/tracing'

if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    integrations: [new Integrations.BrowserTracing()],

    // Set tracesSampleRate to 1.0 to capture 100%
    // of transactions for performance monitoring.
    // We recommend adjusting this value in production
    tracesSampleRate: 1.0,
  })
} else {
  console.log('Sentry is turned off.')
}

export function captureMessage(message, data) {
  if (!process.env.SENTRY_DSN) return

  // Sentry doesn't provide the option of seeing the full message if it's long
  // and Elm decode errors that log the entire data structure are very long
  // and have the useful bit at the very end, which is truncated by Sentry
  const truncatedData = data.length < 2000 ? data : data.slice(0, 1000) + '\n...TRUNCATED...\n' + data.slice(-1000)

  console.log('The following information has been reported:')
  console.log(truncatedData)

  Sentry.captureEvent({
    message,
    breadcrumbs: [{
      message: truncatedData,
    }],
  })
}
