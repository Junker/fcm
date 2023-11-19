(in-package #:fcm)

(defvar *scope* "https://www.googleapis.com/auth/firebase.messaging")
(defvar *token-uri* "https://oauth2.googleapis.com/token")
(defparameter *token-expiry-length* 3600)

(define-condition fcm-error (error)
  ((code :initarg :code
         :reader fcm-error-code
         :type integer)
   (message :initarg :message
            :reader fcm-error-message
            :type string)
   (status :initarg :status
           :reader fcm-error-status
           :type string)
   (details :initarg :details
            :reader fcm-error-details))
  (:report (lambda (condition stream)
             (with-slots (code message status details) condition
               (format stream "FCM request failed with code ~D and status '~A': ~A~% Details:~%~A"
                       code status message (write-to-string details))))))

(defclass client ()
  ((project-id :initarg :project-id :accessor client-project-id :type string)
   (private-key :initarg :private-key :accessor client-private-key :type ironclad:rsa-private-key)
   (client-email :initarg :client-email :accessor client-client-email :type string)
   (token-uri :initarg :token-uri :accessor client-token-uri :type string)
   (access-token :initarg nil :accessor client-access-token)
   (access-token-expires-at :initarg :access-token-expires-at :accessor client-access-token-expires-at :type integer))
  (:default-initargs
   :project-id (error "PROJECT-ID required.")
   :private-key (error "PRIVATE-KEY required.")
   :client-email (error "CLIENT-EMAIL required.")
   :token-uri *token-uri*
   :access-token-expires-at 0))


;; PRIV
(defun parse-service-account-file (path)
  (jojo:parse (uiop:read-file-string path)))

(defun read-pkcs8-private-key (pem)
  (let* ((pkcs8-der (asn1:decode (base64:base64-string-to-usb8-array (cdar (pem:parse (make-string-input-stream pem))))))
         (pkcs1-der (asn1:decode (cdr (fourth (car pkcs8-der))))))
    (trivia:match pkcs1-der
      ((asn1:rsa-private-key :private-exponent d :modulus n)
       (ironclad:make-private-key :rsa :d d :n n)))))

(defun %generate-jwt (private-key client-email token-uri &key (expiry-length *token-expiry-length*))
  (jose:encode :rs256 private-key `(("iss" . ,client-email)
                                    ("iat" . ,(timestamp-to-unix (now)))
                                    ("exp" . ,(+ (timestamp-to-unix (now)) expiry-length))
                                    ("scope" . ,*scope*)
                                    ("aud" . ,token-uri))))


(defun %send (message project-id access-token)
  (handler-case (dex:post (format nil "https://fcm.googleapis.com/v1/projects/~A/messages:send" project-id)
                          :headers `(("Content-Type" . "application/json")
                                     ("Authorization" . ,(format nil "Bearer ~A" access-token)))
                          :content (jojo:to-json (list :|message| message)))
    (dex:http-request-failed (err)
      (if (not (equal (gethash "content-type" (dex:response-headers err))
                      "application/json; charset=UTF-8"))
          (error err)
          (let* ((data (jojo:parse (dex:response-body err)))
                 (error-data (getf data :|error|)))
            (if (not error-data)
                (error err)
                (error (make-condition 'fcm-error
                                       :code (getf error-data :|code|)
                                       :status (getf error-data :|status|)
                                       :message (getf error-data :|message|)
                                       :details (getf error-data :|details|)))))))))

(defun %auth (token-url jwt)
  (jojo:parse (dex:post token-url
                        :content (format nil "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=~A" jwt)
                        :headers '(("Content-Type" . "application/x-www-form-urlencoded")))))

;; PUBLIC

(defun make-client-with-service-account (path)
  (let ((acc (parse-service-account-file path)))
    (make-instance 'client
                   :project-id (getf acc :|project_id|)
                   :private-key (read-pkcs8-private-key (getf acc :|private_key|))
                   :client-email (getf acc :|client_email|)
                   :token-uri (getf acc :|token_uri|))))

(defmethod generate-jwt ((client client))
  (with-slots (private-key client-email token-uri) client
    (%generate-jwt private-key client-email token-uri)))


(defmethod auth ((client client))
  (let ((response (%auth (client-token-uri client) (generate-jwt client))))
    (setf (client-access-token client) (getf response :|access_token|)
          (client-access-token-expires-at client) (+ (get-universal-time)
                                                     (getf response :|expires_in|)))))


(defmethod send ((client client) message)
  (with-slots (project-id access-token access-token-expires-at) client
    (when (> (get-universal-time) (- access-token-expires-at 10))
      (auth client))
    (%send message project-id access-token)))
