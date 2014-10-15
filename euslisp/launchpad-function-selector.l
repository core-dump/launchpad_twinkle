#!/usr/bin/env roseus

;; config/sanple-config.lの設定に従って
;; ボタンを押すと関数を実行するやつ。

(ros::roseus "launchpad_function_selector")
(require :launchpad-twinkle "package://launchpad_twinkle/euslisp/launchpad-twinkle.l")
(ros::load-ros-manifest "sensor_msgs")


(defclass launchpad-function-selector
  :super propertied-object
  :slots (func-alist radio-group-list))

(defmethod launchpad-function-selector
  (:init
   (&optional config-fname &key config-package)
   (if config-fname
       (send self :load-config config-fname :package config-package))
   (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
   )

  ;; configファイルをロードして、設定を反映する
  (:load-config
   (fname &key package)
   (let (config led-funcs non-led-funcs radio-funcs file-path)
     (if package
         (setq file-path (concatenate string (ros::rospack-find package) fname))
       (setq file-path fname))
     (with-open-file
       (stream file-path :direction :input)
       (while (not (setq config (eval (read stream nil :eof))))))
     (when (eq config :eof)
       (warning-message 1 "EOF hit while loading config.~%")
       (return-from :load-config nil))
     (setq led-funcs (cdr (assoc 'led-funcs config)))
     (setq non-led-funcs (cdr (assoc 'non-led-funcs config)))
     (setq radio-funcs (cdr (assoc 'radio-button-funcs config)))

     (print led-funcs)
     (print non-led-funcs)
     (print radio-funcs)

     (reset-led-states)
     (setq func-alist (send self :make-func-alist led-funcs non-led-funcs radio-funcs))
     (send self :init-normal-led led-funcs)
     (send self :init-radio-led radio-funcs)
     (setq radio-group-list (send self :extract-radio-group radio-funcs))
     )
   )

  ;; 専用形式のリストを基に関数とボタンの割り当てリストを作る。
  (:make-func-alist
   (led non-led radio)
   (labels
     ((f (l) (cons (car l) (cadr l))))
     (append
      (mapcar #'f led)
      (mapcar #'f non-led)
      (mapcan #'(lambda (ll) (mapcar #'f ll)) radio))
     )
   )

  ;; 関数リストと光らせないリストを基に光らせるリストを得る。
  ;; もう使ってない気がする。
  (:extract-led-buttons
   (funcs non-led)
   (set-difference (mapcar #'car funcs) non-led)
   )

  ;; 非ラジオLEDの設定をする。
  (:init-normal-led
   (buttons &optional (color :orange))
   (mapc #'(lambda (x) (set-led-state (button2led-id (car x)) color)) buttons)
   (apply-led-states)
   )

  ;; ラジオボタンLEDの設定をする。
  (:init-radio-led
   (radio-groups)
   (mapc #'(lambda (group)
           (set-led-state (button2led-id (caar group)) :red)
           (mapc #'(lambda (button)
                   (set-led-state (button2led-id (car button)) :green))
                 (cdr group)))
         radio-groups)
   (apply-led-states)
   )

  ;; configのradio-groupから番号だけを取り出す。
  (:extract-radio-group
   (radio-funcs)
   (mapcar #'(lambda (group) (mapcar #'car group)) radio-funcs)
   )

  ;; ラジオボタンの更新。
  (:update-radio
   (selected-btn group-btns)
   (set-led-state (button2led-id selected-btn) :red)
   (mapc #'(lambda (button) (set-led-state (button2led-id button) :green))
         (remove selected-btn group-btns))
   (apply-led-states)
   )

  ;; ボタンが押されると対応した関数を実行する。
  (:joy-cb
   (msg)
   (let ((idx (send self :get-idx-from-value (send msg :buttons) 1)))
     (eval (cdr (assoc idx func-alist)))
     (if (member idx (flatten radio-group-list))
         (send self :update-radio idx (mapcan #'(lambda (l) (if (member idx l) l)) radio-group-list))))
   )

  ;; 同時押しの場合は後ろの番号を返す。
  (:get-idx-from-value
   (l value)
   (let ((answer-idx nil))
     (dotimes (idx (length l))
       (if (equal (elt l idx) value) (setq answer-idx idx)))
     answer-idx)
   )

  )

;; midi_config_player待ち。
(unix::sleep 1)
