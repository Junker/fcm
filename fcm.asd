(defsystem "fcm"
  :version "0.1.0"
  :author "Dmitrii Kosenkov"
  :license "MIT"
  :depends-on ("dexador"
               "alexandria"
               "jonathan"
               "cl-base64"
               "local-time"
               "jose"
               "ironclad"
               "asn1"
               "pem")
  :description "Client for FCM - Firebase Cloud Messaging"
  :homepage "https://github.com/Junker/fcm"
  :source-control (:git "https://github.com/Junker/fcm.git")
  :components ((:file "package")
               (:file "fcm")))
