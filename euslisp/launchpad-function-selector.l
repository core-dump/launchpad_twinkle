#!/usr/bin/env roseus

;; config/sanple-config.lの設定に従って
;; ボタンを押すと関数を実行するやつ。

(ros::roseus "launchpad_function_selector")
(require :launchpad-twinkle "package://launchpad_twinkle/euslisp/launchpad-twinkle.l")
(ros::load-ros-manifest "sensor_msgs")


(defclass launchpad-function-selector
  :super propertied-object
  :slots (func-alist))

(defmethod launchpad-function-selector
  (:init
   ()
   (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
   )

  ;; configファイルをロードして、設定を反映する
  (:load-config
   (fname)
   (let ((config (load fname)))
     ()
   )
   )

  ;; 専用形式のリストをもとに関数をボタンに割り当てる
  (:allocate-func
   (flist)
   )

  ;; 関数の割り当てが済んだ前提でLEDの設定をする
  (:apply-led
   ()
   )

  ;; ラジオボタンの更新
  (:update-radio
   (selected-btn group-btns)
   )

  (:joy-cb
   (msg)
   (let ((idx (send self :get-idx-from-value (send msg :buttons) 1)))
     (eval (assoc idx func-alist)))
   )

  ;; 同時押しの場合は後ろの番号を返す
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

(setq *lfs* (instance launchpad-function-selector :init))
(ros::rate 30)
(while (ros::ok)
  (ros::spin-once)
  (ros::sleep)
  )
