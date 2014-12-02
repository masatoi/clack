#|
  This file is a part of Clack package.
  URL: http://github.com/fukamachi/clack
  Copyright (c) 2011 Eitaro Fukamachi <e.arrows@gmail.com>

  Clack is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage clack.app.file
  (:use :cl
        :clack)
  (:import-from :trivial-mimes
                :mime-lookup)
  (:import-from :cl-ppcre
                :scan)
  (:import-from :local-time
                :format-rfc1123-timestring
                :universal-to-timestamp)
  (:import-from :cl-fad
                :file-exists-p
                :directory-exists-p)
  (:import-from :alexandria
                :when-let))
(in-package :clack.app.file)

(cl-syntax:use-syntax :annot)

@export
(defclass <clack-app-file> (<component>)
     ((file :type (or string null)
            :initarg :file
            :initform nil
            :accessor file)
      (root :type pathname
            :initarg :root
            :initform #p"./"
            :accessor root)
      (encoding :type string
                :initarg :encoding
                :initform "utf-8"
                :accessor encoding))
  (:documentation "Clack Application to serve static files."))

(defmethod call ((this <clack-app-file>) env)
  (let ((file (locate-file this
                           (or (file this)
                               ;; remove "/"
                               (subseq (getf env :path-info) 1))
                           (root this))))
    (if (consp file) ;; some error case
        file
        (serve-path this env file (encoding this)))))

(defparameter return-403
              '(403 (:content-type "text/plain"
                     :content-length 9)
                ("forbidden")))

(defparameter return-400
              '(400 (:content-type "text/plain"
                     :content-length 11)
                ("Bad Request")))

(defparameter return-404
              '(404 (:content-type "text/plain"
                     :content-length 9)
                ("not found")))

@export
(defgeneric should-handle (app file)
  (:method ((this <clack-app-file>) file)
    (and (file-exists-p file)
         (not (directory-exists-p file)))))

@export
(defgeneric locate-file (app path root)
  (:method ((this <clack-app-file>) path root)
    (when (find :up (pathname-directory path) :test #'eq)
      (return-from locate-file return-400))

    (let ((file (merge-pathnames path root)))
      (cond
        ((position #\Null (namestring file)) return-400)
        ((not (should-handle this file)) return-404)
;      ((not (find :user-read (file-permissions file)))
;       return-403)
        (t file)))))

(defun text-file-p (content-type)
  (when-let (pos (scan "^text" content-type))
    (= pos 0)))

(defun gz-p (pathname)
  (let ((pathname (if (stringp pathname) (pathname pathname) pathname)))
    (string= (pathname-type pathname) "gz")))

(defun make-pathname-eliminate-gz (pathname)
  (let* ((pathname (if (stringp pathname) (pathname pathname) pathname))
         (unzipped-pathname (pathname (pathname-name pathname)))
         (unzipped-name (pathname-name unzipped-pathname))
         (unzipped-type (pathname-type unzipped-pathname)))
    (make-pathname :host (pathname-host pathname)
                   :device (pathname-device pathname)
                   :directory (pathname-directory pathname)
                   :name unzipped-name
                   :type unzipped-type
                   :version (pathname-version pathname))))

@export
(defgeneric serve-path (app env file encoding)
  (:method ((this <clack-app-file>) env file encoding)
    (let ((content-type (or (clack.util.hunchentoot:mime-type
                             (if (gz-p file) (make-pathname-eliminate-gz file) file))
                            "text/plain"))
          (univ-time (or (file-write-date file)
                         (get-universal-time))))
      (when (text-file-p content-type)
        (setf content-type
              (format nil "~A;charset=~A"
                      content-type encoding)))
      (with-open-file (stream file
                              :direction :input
                              :if-does-not-exist nil)
        `(200
          (:content-type ,content-type
           ,@(if (gz-p file) '(:content-encoding "gzip"))
           :content-length ,(file-length stream)
           :last-modified
           ,(format-rfc1123-timestring nil
                                       (universal-to-timestamp univ-time)))
          ,file)))))

(doc:start)

@doc:NAME "
Clack.App.File - Serve static files.
"

@doc:SYNOPSIS "
    ;; THIS IS JUST FOR EXAMPLE
    (clackup (<clack-app-file>
              :root #p\"./static-files/\"))
    
    ;; Then access 'http://localhost/jellyfish.jpg' through into local './static-files/jellyfish.jpg'.
    ;; If the file isn't found, 404 will be returned.
"

@doc:DESCRIPTION "
Clack.App.File serves static files in local directory. This Application should be used in other Middleware or Application (ex. Clack.Middleware.Static).
"

@doc:AUTHOR "
Eitaro Fukamachi (e.arrows@gmail.com)
"

@doc:SEE "
* Clack.Middleware.Static
"
