#!/usr/bin/env roseus

(ros::roseus "launchpad_twinkle")
(ros::load-ros-manifest "sensor_msgs")
(ros::advertise "/midi_joy/set_feedback" sensor_msgs::JoyFeedbackArray)

;; LEDs
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

(defun pub-led (id intensity)
  (let ((msg (instance sensor_msgs::JoyFeedbackArray :init))
        (msg-elem (instance sensor_msgs::JoyFeedback :init)))
    (send msg-elem :type 0)
    (send msg-elem :id id)
    (cond
      ((equal intensity :off)        (setq intensity 0))
      ((equal intensity :red)        (setq intensity 0.024))
      ((equal intensity :green)      (setq intensity 0.980))
      ((equal intensity :yellow)     (setq intensity 0.990))
      ((equal intensity :orange)     (setq intensity 1.000))
      ((equal intensity :red-orange) (setq intensity 0.150)))
    (send msg-elem :intensity intensity)
    (send msg :array (list msg-elem))
    (ros::publish "/midi_joy/set_feedback" msg)))

;; nilに注意。
(defun button2led-id (button-id)
  (let (led-id)
    (cond
     ((eq button-id nil)
      (setq led-id nil))
     ((and (>= button-id 0) (<= button-id 7))
      (setq led-id (+ (* button-id 9) 16)))
     ((and (>= button-id 8) (<= button-id 71))
      (setq led-id (+ (* (/ button-id 8) 9) (mod button-id 8) -1))))
    led-id))

(defun radio-button-led (selected-id id-list)
  (dolist (id id-list)
    (if (= id selected-id)
        (pub-led id :red)
      (pub-led id :green))))

;; step: 0.01 ~ 0.0001 を推奨
(defun pattern (&optional (step 0.001))
  (let ((seed 0) (intensity 0))
    (do-until-key
      (setq intensity seed)
      (dotimes (i 8)
        (dotimes (j 8)
          (pub-led (+ (* i 9) j 8) intensity)
          (setq intensity (+ intensity step))
          (if (> intensity 1) (setq intensity 0))
          ))
      (setq seed (+ seed step))
      (when (> seed 1) (setq seed 0) (print "reset seed"))
      (unix::usleep (round (* 10000000000 step step))))))

;; intensity example
;; * * *
;; off: 0
;; red: 0.008, 0.016brighter, 0.024brighter
;; green: 0.126, 0.980brighter
;; yellow: 0.958, 0.990
;; orange: 0.134, 1.000brighter
;; red-orange: 0.142, 0.150brighter
