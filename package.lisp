(defpackage fcm
  (:use #:cl #:alexandria)
  (:import-from #:local-time
                #:timestamp-to-unix
                #:now)
  (:export #:*token-expiry-length*
           #:client
           #:send
           #:auth
           #:generate-jwt
           #:make-client-with-service-account
           #:fcm-error
           #:fcm-error-code
           #:fcm-error-message
           #:fcm-error-status
           #:fcm-error-details))
