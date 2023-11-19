# FCM

Common Lisp client for FCM - Firebase Cloud Messaging.

## Installation

This system can be installed from [UltraLisp](https://ultralisp.org/) like this:

```common-lisp
(ql-dist:install-dist "http://dist.ultralisp.org/"
                      :prompt nil)
(ql:quickload "fcm")
```

## Usage

```common-lisp
(defvar *fcm* (fcm:make-client-with-service-account  "config/firebase.json"))
(defvar *token* "some-device-token")
(defvar *message*
  (list :|token| *token*
        :|notification| (list :|title| "Message Title"
                              :|body| "Message body"
                              :|image| "https://example.org/logo.jpg")))

(handler-case (fcm:send *fcm* *message*)
  (fcm:fcm-error (err)
    (case (intern (fcm:fcm-error-status err))
      ('NOT_FOUND
       (log:warn "unregistered FCM token: ~A" *token*))
      (t
       (log:error "FCM error: ~A: ~A; token: ~A" (type-of err) err *token*)))))

```

## Documentation

- [FCM Message format](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
