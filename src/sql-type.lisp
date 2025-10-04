(defpackage #:sxql/sql-type
  (:nicknames #:sxql.sql-type)
  (:use #:cl)
  (:export
   ;; Special variables
   #:*quote-character*
   #:*use-placeholder*
   ;; Macros
   #:with-yield-binds
   #:with-table-name
   ;; Types
   #:sql-atom
   #:sql-variable
   #:sql-keyword
   #:sql-symbol
   #:sql-list
   #:sql-splicing-list
   #:sql-op
   #:sql-column-type
   #:sql-clause
   #:sql-clause-list
   #:sql-expression
   #:sql-expression-list
   #:sql-splicing-expression-list
   #:sql-statement
   #:unary-op
   #:unary-splicing-op
   #:unary-postfix-op
   #:infix-op
   #:infix-splicing-op
   #:infix-list-op
   #:conjunctive-op
   #:function-op
   #:expression-clause
   #:statement-clause
   #:expression-list-clause
   #:sql-composed-statement
   ;; Constructors
   #:make-sql-variable
   #:make-sql-keyword
   #:make-sql-symbol
   #:make-sql-symbol*
   #:make-sql-list
   #:make-sql-splicing-list
   #:make-sql-column-type
   #:make-sql-expression-list
   #:make-sql-splicing-expression-list
   #:make-unary-op
   #:make-unary-splicing-op
   #:make-infix-op
   #:make-infix-splicing-op
   #:make-infix-list-op
   #:make-conjunctive-op
   #:make-function-op
   #:make-type-keyword
   ;; Accessors
   #:sql-variable-value
   #:sql-list-elements
   #:sql-statement-name
   #:sql-statement-children
   #:sql-composed-statement-children
   ;; Slot accessors
   #:elements
   #:name
   #:var
   #:left
   #:right
   #:expressions
   #:expression
   #:statement
   #:children
   ;; Functions
   #:sql-expression-list-p
   #:sql-symbol-p
   #:sql-symbol-name
   #:yield))
(in-package #:sxql/sql-type)

(cl-package-locks:lock-package '#:sxql/sql-type)

(defparameter *quote-character* nil)

(defparameter *use-placeholder* t)

(defparameter *bind-values* nil)
(defparameter *use-global-bind-values* nil)
(defparameter *inside-function-op* nil)

(defmacro with-yield-binds (&body body)
  `(let ((*bind-values* nil)
         (*use-global-bind-values* t))
     (values
      (progn ,@body)
      (loop for bind in (reverse *bind-values*)
            append bind))))

;;
;; Atom

(defstruct sql-atom)

(defstruct (sql-variable (:include sql-atom)
                         (:constructor make-sql-variable (value)))
  (value nil :type (or string number (vector (unsigned-byte 8)) array)))

(defstruct (sql-keyword (:include sql-atom)
                        (:constructor make-sql-keyword (name)))
  (name nil :type string))

(defstruct (sql-symbol (:include sql-atom)
                       (:constructor %make-sql-symbol))
  (name nil :type string)
  (tokens nil :type cons))

(defun make-sql-symbol (name)
  (%make-sql-symbol :name name
                    :tokens (uiop:split-string name :separator ".")))

(defun make-sql-symbol* (tokens)
  (let ((tokens (if (listp tokens)
                    tokens
                    (list tokens))))
    (%make-sql-symbol :name (format nil "~{~A~^.~}" tokens)
                      :tokens tokens)))

(defstruct (sql-list (:constructor make-sql-list (&rest elements)))
  (elements nil :type list))

(defstruct (sql-splicing-list (:include sql-list)
                              (:constructor make-sql-splicing-list (&rest elements))))

(defstruct sql-op
  (name nil :type string))

(defmethod print-object ((op sql-op) stream)
  (format stream "#<SXQL-OP: ~A>"
          (let ((*use-placeholder* nil))
            (yield op))))

(defstruct (sql-column-type (:constructor make-sql-column-type (name &key args attrs
                                                                &aux (name (make-type-keyword name)))))
  (name nil)
  (args nil :type list)
  (attrs nil :type list))

(defun make-type-keyword (type)
  (typecase type
    (string (make-sql-keyword type))
    (symbol (make-sql-keyword (string-upcase type)))
    (t type)))


(defstruct sql-clause
  (name "" :type string))

(defun sql-clause-list-p (object)
  (every #'sql-clause-p object))

(deftype sql-clause-list ()
  '(and list
        (satisfies sql-clause-list-p)))

(deftype sql-expression () '(or sql-atom sql-list sql-op sql-clause null))

(defun sql-expression-p (object)
  (typep object 'sql-expression))

(defun sql-expression-list-p (object)
  (every #'sql-expression-p object))

(defstruct (sql-expression-list (:constructor make-sql-expression-list (&rest elements))
                                (:predicate nil))
  (elements nil :type (and list
                         (satisfies sql-expression-list-p))))

(defstruct (sql-splicing-expression-list (:include sql-expression-list)
                                         (:constructor make-sql-splicing-expression-list (&rest elements))))

(defstruct sql-statement
  (name "" :type string))

(deftype sql-all-type () '(or sql-expression sql-statement))

(defun sql-statement-list-p (object)
  (every #'(lambda (element)
             (typep element 'sql-all-type))
         object))

;;
;; Operator

(defstruct (unary-op (:include sql-op)
                     (:constructor make-unary-op (name var)))
  (var nil :type (or sql-statement
                     sql-expression)))

(defstruct (unary-splicing-op (:include unary-op)
                              (:constructor make-unary-splicing-op (name var))))

(defstruct (unary-postfix-op (:include unary-op)))

(defstruct (infix-op (:include sql-op)
                     (:constructor make-infix-op (name left right)))
  (left nil :type (or sql-statement
                    sql-expression
                    sql-expression-list))
  (right nil :type (or sql-statement
                     sql-expression
                     sql-expression-list)))

(defstruct (infix-splicing-op (:include infix-op)
                              (:constructor make-infix-splicing-op (name left right))))

(defstruct (infix-list-op (:include sql-op))
  (left nil :type sql-expression)
  (right nil :type (or list
                       sql-statement)))

(defstruct (conjunctive-op (:include sql-op)
                           (:constructor make-conjunctive-op (name &rest expressions)))
  (expressions nil :type (and list
                            (satisfies sql-statement-list-p))))

(defstruct (function-op (:include conjunctive-op)
                        (:constructor make-function-op (name &rest expressions))))

;;
;; Clause

(defstruct (expression-clause (:include sql-clause))
  (expression nil :type (or sql-expression
                           sql-expression-list)))

(defstruct (statement-clause (:include sql-clause))
  (statement nil :type (or sql-expression
                         sql-expression-list
                         sql-statement)))

(defstruct (expression-list-clause (:include sql-clause))
  (expressions nil :type (and list
                            (satisfies sql-expression-list-p))))

(defmethod print-object ((clause sql-clause) stream)
  (format stream "#<SXQL-CLAUSE: ~A>"
          (let ((*use-placeholder* nil))
            (yield clause))))

;;
;; Statement

(defstruct (sql-composed-statement (:include sql-statement))
  (children nil :type list))

(defmethod print-object ((clause sql-statement) stream)
  (format stream "#<SXQL-STATEMENT: ~A>"
          (let ((*use-placeholder* nil))
            (yield clause))))

;;
;; Yield

(defgeneric yield (object))

(defparameter *table-name-scope* nil)
(defmacro with-table-name (table-name &body body)
  `(let ((*table-name-scope* ,table-name))
     ,@body))

(defmethod yield ((var-list list))
  (format nil "(~{~A~^, ~})"
          (mapcar #'yield var-list)))

(defmethod yield ((symbol sql-symbol))
  (let ((tokens (sql-symbol-tokens symbol)))
    (when (and *table-name-scope*
               (null (cdr tokens)))
      (push *table-name-scope* tokens))
    (values
     (loop for token in tokens
           if (string= token "*")
             collect token into tokens
           else
             collect (format nil "~A~A~A"
                             (or *quote-character* "")
                             token
                             (or *quote-character* "")) into tokens
           finally
              (return (format nil "~{~A~^.~}" tokens)))
     nil)))

(defmethod yield ((keyword sql-keyword))
  (values
   (sql-keyword-name keyword)
   nil))

(defmethod yield ((var sql-variable))
  (if *use-placeholder*
      (values "?" (list (sql-variable-value var)))
      (values
       (if (stringp (sql-variable-value var))
           (format nil "'~A'"
                   (sql-variable-value var))
           (princ-to-string (sql-variable-value var)))
       nil)))

(defmethod yield ((list sql-list))
  (with-yield-binds
    (format nil "(~A)"
            (yield
             (apply #'make-sql-splicing-list
                    (sql-list-elements list))))))

(defmethod yield ((list sql-splicing-list))
  (with-yield-binds
    (format nil "~{~A~^, ~}"
            (mapcar (lambda (element)
                      (if (sql-statement-p element)
                          (format nil "(~A)" (yield element))
                          (yield element)))
                    (sql-list-elements list)))))

(defmethod yield ((list sql-expression-list))
  (with-yield-binds
    (format nil "(~{~A~^ ~})"
            (mapcar #'yield (sql-expression-list-elements list)))))

(defmethod yield ((list sql-splicing-expression-list))
  (with-yield-binds
    (format nil "~{~A~^ ~}"
            (mapcar #'yield (sql-expression-list-elements list)))))

(defmethod yield ((op unary-op))
  (multiple-value-bind (var binds)
      (yield (unary-op-var op))
    (values (format nil "(~A ~A)"
                    (sql-op-name op)
                    var)
            binds)))

(defmethod yield ((op unary-splicing-op))
  (multiple-value-bind (var binds)
      (yield (unary-op-var op))
    (values (format nil "~A ~A"
                    (sql-op-name op)
                    var)
            binds)))

(defmethod yield ((op unary-postfix-op))
  (multiple-value-bind (var binds)
      (yield (unary-op-var op))
    (values (format nil "~A ~A"
                    var
                    (sql-op-name op))
            binds)))

(defmethod yield ((op infix-op))
  (flet ((f (left-or-right)
           (if (sql-statement-p left-or-right)
               (format nil "(~A)" (yield left-or-right))
               (yield left-or-right))))
    (with-yield-binds
      (format nil "(~A ~A ~A)"
              (f (infix-op-left op))
              (sql-op-name op)
              (f (infix-op-right op))))))

(defmethod yield ((op infix-splicing-op))
  (with-yield-binds
    (format nil "~A ~A ~A"
            (if (sql-statement-p (infix-op-left op))
                (yield (make-sql-list (infix-op-left op)))
                (yield (infix-op-left op)))
            (sql-op-name op)
            (if (sql-statement-p (infix-op-right op))
                (yield (make-sql-list (infix-op-right op)))
                (yield (infix-op-right op))))))

(defmethod yield ((op infix-list-op))
  (with-yield-binds
    (format nil "(~A ~A ~A)"
            (yield (infix-list-op-left op))
            (sql-op-name op)
            (if (sql-statement-p (infix-list-op-right op))
                (format nil "(~A)" (yield (infix-list-op-right op)))
                (yield (apply #'make-sql-list (infix-list-op-right op)))))))

(defmethod yield ((op conjunctive-op))
  (with-yield-binds
    (if (cdr (conjunctive-op-expressions op))
        (format nil (format nil "(~~{~~A~~^ ~A ~~})" (sql-op-name op))
                (mapcar #'yield (conjunctive-op-expressions op)))
        (yield (car (conjunctive-op-expressions op))))))

(defmethod yield ((op function-op))
  (let ((*inside-function-op* t))
    (with-yield-binds
      (format nil "~A(~{~A~^, ~})"
              (sql-op-name op)
              (mapcar #'yield (function-op-expressions op))))))

(defmethod yield ((type sql-column-type))
  (let ((*use-placeholder* nil)
        (args (sql-column-type-args type)))
    (format nil "~A~:[~;~:*(~{~A~^, ~})~]~{ ~A~}"
            (yield (sql-column-type-name type))
            (mapcar #'yield args)
            (mapcar #'yield (sql-column-type-attrs type)))))

(defmethod yield ((clause expression-clause))
  (multiple-value-bind (sql bind)
      (yield (expression-clause-expression clause))
    (values
     (format nil "~A ~A"
             (sql-clause-name clause)
             sql)
     bind)))

(defmethod yield ((clause statement-clause))
  (with-yield-binds
    (format nil (if (sql-statement-p (statement-clause-statement clause))
                  "~:[~A ~;~*~](~A)"
                  "~:[~A ~;~*~]~A")
            (string= (sql-clause-name clause) "")
            (sql-clause-name clause)
            (yield (statement-clause-statement clause)))))

(defmethod yield ((clause expression-list-clause))
  (with-yield-binds
    (format nil "~A ~{~A~^, ~}"
            (sql-clause-name clause)
            (mapcar #'yield (expression-list-clause-expressions clause)))))

(defmethod yield ((statement sql-composed-statement))
  (with-yield-binds
    (format nil (if *inside-function-op*
                    "(~A ~{~A~^ ~})"
                    "~A ~{~A~^ ~}")
            (sql-statement-name statement)
            (mapcar #'yield (sql-composed-statement-children statement)))))

(defmethod yield :around ((object t))
  (if *use-global-bind-values*
      (progn
        (multiple-value-bind (var bind) (call-next-method)
          (when bind (push bind *bind-values*))
          (values var nil)))
      (call-next-method)))
