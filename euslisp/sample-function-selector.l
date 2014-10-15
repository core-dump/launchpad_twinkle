#!/usr/bin/env roseus
;; ボタンを押すと関数を実行するやつの使い方。
;; (好きなパッケージの)好きなファイルの中でこのように呼び出せる。

(ros::roseus "sample_function_selector")
(require :launchpad-function-selector
         "package://launchpad_twinkle/euslisp/launchpad-function-selector.l")
;; 必要なファイルをロード。(今はエラーが出るのでコメントアウト)
;; (require :samplerobot-interface
;;          "package://hrpsys_ros_bridge_tutorials/euslisp/samplerobot-interface")

;; 好きな処理を書く。
;; (samplerobot-init)
;; (objects (list *sr*))

;; 実際にmidiコントローラを使う部分は以下。
(setq *lfs* (instance launchpad-function-selector
                      :init "/config/sample-config.l" :config-package "launchpad_twinkle"))
(ros::rate 30)
(while (ros::ok)
  (ros::spin-once)
  (ros::sleep)
  )
