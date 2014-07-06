#!/usr/bin/env roseus

(ros::roseus "launchpad_change_color")
(require :launchpad-twinkle "package://launchpad_twinkle/euslisp/launchpad-twinkle.l")
(ros::load-ros-manifest "sensor_msgs")
(ros::advertise "/midi_joy/set_feedback" sensor_msgs::JoyFeedbackArray)

;; axes
;; -------------------
;;  0  1 ...  6  7
;; -- -- --- -- --
;; 16 17 ... 22 23 | 8
;; 24 25 ... 30 31 | 9
;;  .  . .    .  . | .
;;  .  .   .  .  . | .
;; 64 65 ... 70 71 | 14
;; 72 73 ... 78 79 | 15
;; -------------------

;; board, LEDs
;; -------------------
;;  0  1 ...  6  7
;; -- -- --- -- --
;;  8  9 ... 14 15 | 16
;; 17 18 ... 23 24 | 25
;;  .  . .    .  . | .
;;  .  .   .  .  . | .
;; 62 63 ... 68 69 | 70
;; 71 72 ... 77 78 | 79
;; -------------------

(defclass launchpad-change-color
  :super object
  :slots (prev-input-button state-list))
;; state-listはboardのidで表す。

(defmethod launchpad-change-color
  (:init
    ()
    (setq prev-input-button nil)
    (setq state-list (make-list 80 :initial-element 0))
    (dotimes (idx (length state-list))
      (send self :state2led idx))
    (ros::subscribe "/joy" sensor_msgs::Joy #'send self :joy-cb)
    )

  (:button2board-id
    (bt-id)
    (let (ans)
      (cond ((eq bt-id nil)
             (setq ans nil))
            ((and (>= bt-id  0) (<= bt-id  7))
             (setq ans bt-id))
            ((and (>= bt-id  8) (<= bt-id 15))
             (setq ans (+ (* (- bt-id 8) 9) 16)))
            ((and (>= bt-id 16) (<= bt-id 79))
             (setq ans (+ (* (/ bt-id 8) 9) (mod bt-id 8) -10)))
            (t
              (setq ans nil))))
    )

  (:board2led-id (bo-id) bo-id)

  (:state2led ;; stateに応じて光らせる
    (bo-id)
    (if (eq bo-id nil) (return-from :state2led))
    (let ((state (elt state-list bo-id)) ;;はみ出したら死ぬ
          (l-id (send self :board2led-id bo-id)))
      (case state
        (0 (pub-led l-id :off))
        (1 (pub-led l-id :red))
        (2 (pub-led l-id :orange))
        (3 (pub-led l-id :yellow))
        (4 (pub-led l-id :green))))
    )

  (:change-state
   (bo-id)
   (let (new-state)
     (setq new-state (1+ (elt state-list bo-id)))
     (if (>= new-state 5)
         (setq new-state 0))
     (setelt state-list bo-id new-state))
   )

  (:joy-cb
    (msg)
    ;; (setq tmp msg)
    (let ((button-id (get-idx-from-value (send msg :axes) 1.0))
          (target-id))
      ;; 直前と同じボタン
      (if (eq button-id prev-input-button)
        (return-from :joy-cb))
      (setq prev-input-button button-id)
      ;; ボタン離したとき
      (if (eq button-id nil)
          (return-from :joy-cb))

      (setq target-id (send self :button2board-id button-id))
      ;; (format t "(~a, ~a)~%" button-id target-id)
      (send self :change-state target-id)
      (dotimes (idx (length state-list))
        (send self :state2led idx))
      ))

  )

;; atlasmarion/midi-gazebo-cotroller.lからコピペ
;; 1と1.0だと一致しないことに注意
(defun get-idx-from-value (l value)
  (let ((answer-idx nil))
    (dotimes (idx (length l))
      (if (equal (elt l idx) value) (setq answer-idx idx)))
    answer-idx))

(unix::sleep 1)
(setq *launchpad-change-color* (instance launchpad-change-color :init))
(ros::rate 30)
(while (ros::ok)
  (ros::spin-once)
  (ros::sleep))
