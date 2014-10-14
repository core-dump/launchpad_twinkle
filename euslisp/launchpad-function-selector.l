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
   (&optional config-fname)
   (if config-fname
       (send self :load-config config-fname))
   (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
   )

  ;; configファイルをロードして、設定を反映する
  (:load-config
   (fname &key package)
   (let (config non-led led radio file-path)
     (if package
         (setq file-path (concatenate string (ros::rospack-find package) fname))
       (setq file-path fname))
     (with-open-file
       (stream file-path :direction :input)
       (while (not (setq config (eval (read stream nil :eof))))))
     (when (eq config :eof)
       (warning-message 1 "EOF hit while loading config.~%")
       (return-from :load-config nil))
     (setq funcs (cdr (assoc 'funcs config)))
     (setq non-led (cadr (assoc 'non-led config)))
     (setq radios (cdr (assoc 'radio-buttons config)))

     (reset-led-states)
     (setq func-alist (send self :make-func-alist funcs))
     (send self :init-normal-led (send self :extract-led-buttons funcs non-led))
     (send self :init-radio-led radios)
     (setq radio-group-list (copy-object radios))
     )
   )

  ;; 専用形式のリストを基に関数とボタンの割り当てリストを作る。
  (:make-func-alist
   (funcs)
   (mapcar
    #'(lambda (x) (cons (car x) (cadr x)))
    funcs)
   )

  ;; 関数リストと光らせないリストを基に光らせるリストを得る。
  (:extract-led-buttons
   (funcs non-led)
   (set-difference (mapcar #'car funcs) non-led)
   )

  ;; 非ラジオLEDの設定をする。
  (:init-normal-led
   (buttons &optional (color :orange))
   (mapc #'(lambda (x) (set-led-state x color)) buttons)
   (apply-led-states)
   )

  ;; ラジオボタンLEDの設定をする。
  (:init-radio-led
   (radio-groups)
   (mapc #'(lambda (group)
           (set-led-state (car group) :red)
           (mapc #'(lambda (button)
                   (set-led-state button :green))
                 (cdr group)))
         radio-groups)
   (apply-led-states)
   )

  ;; ラジオボタンの更新。
  (:update-radio
   (selected-btn group-btns)
   (set-led-state selected-btn :red)
   (mapc #'(lambda (button) (set-led-state button :green)) (remove selected-btn group-btns))
   (apply-led-states)
   )

  ;; ボタンが押されると対応した関数を実行する。
  (:joy-cb
   (msg)
   (let ((idx (send self :get-idx-from-value (send msg :buttons) 1)))
     (eval (cdr (assoc idx func-alist))))
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
