;;; techela.el --- utilities for techela packages

;; Copyright (C) 2014 John Kitchin

;; Author: John R. Kitchin <jkitchin@andrew.cmu.edu>
;; Version: 0.1
;; Package-Requires: ()
;; Keywords: education



;;; Commentary:

;; This package provides utilities for org-course packages. It
;; provides several new link types:
;; pgk:package|file-in-package to make links between installed packages.
;; assignment:label creates an assignment in the user course directory
;; exercise:label creates an exercise in the user course directory
;; ans:string stores the value of string in a property of the current org-headline
;;
;; It provides an email function

(defun get-pkg-file (pkg fname)
  "return absolute path to fname located in this package"
  (expand-file-name
   fname
   (let* ((pkg-name (symbol-name pkg)) ; convert symbol to string
	  (desc (cdr (assq pkg package-alist)))
	  (version (package-version-join (package-desc-vers desc)))
	  (pkg-dir (package--dir pkg-name version)))
     pkg-dir)))

(org-add-link-type
 "pkg"
 (lambda (path)
   (let ((pkg-name) (relpath)(pkg-dir) (link-string)
         (splitpath (split-string path "|")))
     (setq pkg-name (car splitpath))
     (setq relpath (nth 1 splitpath))
     (setq pkg-dir (file-name-directory
                    (or (locate-library pkg-name)
                        (locate-library (format "%s-autoloads" pkg-name)))))
(setq link-string (format "[[file:%s/%s]]" pkg-dir relpath))
     (message "link: %s" link-string)
     (org-open-link-from-string link-string))))

(defun course-email ()
  "Construct and send an email about a bug/typo/question in the book.

The email body will contain
1. an optional message from the user.
2. the current line text
3. the git revision number
4. Some lisp code to make it trivial to open the file up to exactly the point."
  (interactive)

  ; create the lisp code that will open the file at the point
  (let* ((lisp-code (format "[[elisp:(progn (find-file \"%s\") (goto-char %d))]]"
			    (file-truename (buffer-file-name)) (point)))
	 ;; now create the body of the email
	 (email-body (format "Type your note below here, and press C-c C-c when you are done to send it:



======================================================
Line where point was:
%s: %s
======================================================
Lisp code that opens file at point
%s
======================================================"
          (what-line)
          (thing-at-point 'line)
          lisp-code)))
    (compose-mail-other-frame)
    (message-goto-to)
    (insert "jkitchin@andrew.cmu.edu")
    (message-goto-subject)
    (insert "[21-126] email")
    (message-goto-body)
    (insert email-body)
    (message-goto-body) ; go back to beginning of email body
    (forward-line 2)         ; and down two lines
    (message "Type C-c C-c to send message")))



(defun org-course-assignment (label)
  "open assignment, and save to your directory to work on it. Open your version if it exists.

examples of label:
1. assignments/hwk1   will have assignments/hwk1/hwk1.org
2. exercises/ex1 will have exercises/ex1/ex1.org
"

  (interactive "sEnter assignment label: ")

  (let ((user-root (concat (getenv "HOME") "/org-course/"))
	;; need to figure out how to have a file local variable of what course you are in
	(current-course '21-126)
        (file-to-copy)
        (user-file))

    ;; file from course to copy
    (setq file-to-copy (get-pkg-file current-course (concat label ".org")))
    (setq user-file (concat
                     user-root
		     (symbol-name current-course) "/"
                     (file-name-directory label)
                     (file-name-nondirectory label)
                     "/"
                     (file-name-nondirectory label)
                     ".org"))

    (unless (file-exists-p file-to-copy)
      (error "Could not find %s" file-to-copy))

    (cond
     ;; user-file exists, so open it.
     ((file-exists-p user-file)
      (find-file user-file))
     ;; user-file does not exist, so make dirs and copy
     (t
      (progn
        (make-directory (file-name-directory user-file) t)
        (with-temp-file user-file
              (insert (format "#+NAME: %s
#+ANDREWID: %s
#+EMAIL: %s\n" (user-full-name) (user-login-name) user-mail-address))
              (insert-file-contents file-to-copy)))))))


(org-add-link-type
 "assignment"
 (lambda (arg)
   (org-course-assignment (format "assignments/%s" arg))))


(org-add-link-type
 "exercise"
 (lambda (arg)
   (org-course-assignment (format "exercises/%s" arg))))


(org-add-link-type
 "ans"
 (lambda (path)
   (let* ((correct-answer (org-entry-get (point) "CORRECT-ANSWER"))
          (ncorrect (org-entry-get (point) "NUM-CORRECT"))
          (num-correct (if ncorrect (string-to-number ncorrect) 0))
          (nincorrect (org-entry-get (point) "NUM-INCORRECT"))
          (num-incorrect (if nincorrect (string-to-number nincorrect) 0)))
     (if (string= path correct-answer)
         (progn
          (org-entry-put (point) "NUM-CORRECT" (number-to-string (+ num-correct 1)))
          (message "correct"))
       (org-entry-put (point) "NUM-INCORRECT" (number-to-string (+ num-incorrect 1)))
       (message "incorrect")))))


(provide 'techela)

;;; techela.el ends here
