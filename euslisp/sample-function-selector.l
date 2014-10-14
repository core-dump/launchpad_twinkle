#!/usr/bin/env roseus

;; ボタンを押すと関数を実行するやつの使い方。

(ros::roseus "sample_function_selector")
(require :launchpad-function-selector
         "package://launchpad_twinkle/euslisp/launchpad-function-selector.l")
;; (require :samplerobot-interface "package://hrpsys_ros_bridge_tutorials/euslisp/samplerobot-interface")

;; (samplerobot-init)
;; (objects (list *sr*))

(setq *lfs* (instance launchpad-function-selector :init "sample-config.l"))
(ros::rate 30)
(while (ros::ok)
  (ros::spin-once)
  (ros::sleep)
  )
