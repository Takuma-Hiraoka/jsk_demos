;; robotの初期化
;; (load "package://dxl_armed_turtlebot/euslisp/dxl-armed-turtlebot-interface.l")
;; (dxl-armed-turtlebot-init)

;; jsk_pcl_rosのmsgを使うため、loadする
;;(ros::load-ros-manifest "jsk_pcl_ros")
(ros::roseus-add-msgs "jsk_recognition_msgs")

;; クラスタリング結果であるBoundingBoxのtopic名
;;(defvar *topic-name* "/camera/depth_registered/cluster_decomposer/boxes")
(defvar *topic-name* "/kinect_head/depth_registered/boxes")
(defvar *bounding-box-list* nil)



(setq kct (send *pr2* :head_mount_kinect_rgb_optical_frame_lk))

(setq target (make-coords))


;; コールバック関数(使わない)
(defun bounding-box-array-cb (msg)
  (setq *bounding-box-list* (send msg :boxes)) ;; boxesは、BoundingBoxのArray(Euslispではlist)
  ;; BoundingBoxがあれば表示する
  (when *bounding-box-list*
    (send *irtviewer* :draw-objects :flush nil)
    (mapcar #'(lambda (b)
                ;; BoundingBoxは、dimensions(直方体の幅・奥行き・高さ)をもつ
                (let* ((dims (ros::tf-point->pos (send b :dimensions)))
                       (bx (make-cube (elt dims 0) (elt dims 1) (elt dims 2)))
                       ;; (1) BoundingBoxのカメラ相対の座標系は、geometry_msgs/Poseという型で得られるので、Euslispのcoordsに変換する
                       (cam->obj-coords (ros::tf-pose->coords (send b :pose)))
                       ;; (2) *dxl-armed-turtlebot*モデルがカメラの座標系をもってるので、取得する
                       ;; (cam-coords (send (send *dxl-armed-turtlebot* :camera_rgb_optical_frame_lk) :copy-worldcoords)))
		       (cam-coords (send kct :copy-worldcoords)))
		       ;; (cam-coords (send (send (send *pr2* :head_mount_kinect_ir_link_lk) :copy-worldcoords) :orient 1.57 :z)))
		       ;; (cam-coords (send (send *pr2* :head_mount_kinect_ir_link_lk) :copy-worldcoords)))
                  ;; (3) Euslisp内部でのworld座標系の値にして、そこにmake-cubeの箱を設置する
                  (send bx :newcoords (send cam-coords :transform cam->obj-coords))
                  (send bx :worldcoords)
                  (send bx :draw-on :flush nil :color #f(1 0 0)) ;; 描画
                  bx))
            *bounding-box-list*)
    (send *irtviewer* :viewer :viewsurface :flush)
    (send (send *pr2* :head_mount_kinect_ir_link_lk) :draw-on :flush t)
    ))

;; ソートされたboxについてのコールバック関数
(defun bounding-box-array-sorted-cb (msg)
  (setq *bounding-box-list* (send msg :boxes)) ;; boxesは、BoundingBoxのArray(Euslispではlist)
  ;; BoundingBoxがあれば表示する
  (when *bounding-box-list*
    (send *irtviewer* :draw-objects :flush nil)
    (let* ((b (elt *bounding-box-list* 0))
	   (dims (ros::tf-point->pos (send b :dimensions)))
	   (bx (make-cube (elt dims 0) (elt dims 1) (elt dims 2)))
	   (cam->obj-coords (ros::tf-pose->coords (send b :pose)))
	   (cam-coords (send kct :copy-worldcoords)))

      (send bx :newcoords (send cam-coords :transform cam->obj-coords))
      (send bx :worldcoords)
      (send bx :draw-on :flush nil :color #f(1 0 0)) ;; 描画
      (setq target bx)
      )
    (send *irtviewer* :viewer :viewsurface :flush)
    (send (send *pr2* :head_mount_kinect_ir_link_lk) :draw-on :flush t)
    ))

(defun get-file-pos ()
  ;; ros::initする
  (ros::roseus "boundingboxarray_subscriber")

  (ros::subscribe *topic-name* jsk_recognition_msgs::BoundingBoxArray #'bounding-box-array-sorted-cb 1)

  (do-until-key
   (x::window-main-one) ;; IRT viewerの視点を変えられる。見にくければ変えよう
   (ros::spin-once)
   (ros::sleep)
   )
  (format t "~A~%" (send target :worldcoords))
  (send target :worldcoords)
  )