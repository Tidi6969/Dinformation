;;[原创]动态查询资讯程式
;;
;;功能：动态查询
;;文件：id.lsp
;;命令：idd
;;作者：win-win 修改
;;时间：2004.9.29
;;
(setvar "cmdecho" 0)
(command "ucs" "w")
(setvar "cmdecho" 1)
(defun C:idd (/ myerr dxf toang fx add_solid add_text dis olderr oldos oldfill ss pd 
             gr pt ent entold
            ) 
  (defun myerr (msg) 
    (setq *error* olderr)
    (command "_.undo" "_b")
    (princ)
  )
  (defun dxf (ent i) 
    (if (= (type ent) 'ename) 
      (setq ent (entget ent))
    )
    (cdr (assoc i ent))
  )
  (defun toang (ang i) 
    (if (= i 1) 
      (* ang (/ 180 pi))
      (* ang (/ pi 180))
    )
  )
  (defun fx (ang) 
    (cond 
      ((>= (/ pi 2) ang 0) (list pi (+ pi (/ pi 2)) 1))
      ((>= pi ang (/ pi 2)) (list 0 (+ pi (/ pi 2)) 1))
      ((>= (+ pi (/ pi 2)) ang pi) (list 0 (/ pi 2) 0))
      ((>= (* 2 pi) ang (+ pi (/ pi 2))) (list pi (/ pi 2) 0))
    )
  )
  (defun add_solid (p1 p2 p3 p4) 
    (entmakex 
      (list (cons 0 "SOLID") 
            (cons 100 "AcDbEntity")
            (cons 62 1)
            (cons 100 "AcDbTrace")
            (cons 10 p1)
            (cons 11 p2)
            (cons 12 p3)
            (cons 13 p4)
      )
    )
  )
  (command "ucs" "w")
  (defun add_text (pt h ang txt style jus) 
    (entmakex 
      (list (cons 0 "TEXT") 
            (cons 100 "AcDbEntity")
            (cons 62 2)
            (cons 100 "AcDbText")
            (if (= jus 0) (cons 10 pt) (list 10 0.0 0.0 0.0))
            (cons 40 h)
            (cons 1 txt)
            (cons 50 ang)
            (cons 7 style)
            (cons 72 
                  (cond ((= jus 0) 0) ((= jus 1) 1) ((= jus 2) 1) ((= jus 3) 2))
            )
            (if (= jus 0) 
              (list 11 0.0 0.0 0.0)
              (cons 11 pt)
            )
            (cons 100 "AcDbText")
            (cons 73 
                  (cond ((= jus 0) 0) ((= jus 1) 2) ((= jus 2) 3) ((= jus 3) 2))
            )
      )
    )
  )
  (defun dis (ent / obj laynm name st1 st2 st3 lst h ang n) 
    (setq obj (vlax-ename->vla-object ent))
    (setq laynm (strcat "Layer: " (dxf ent 8))
          name  (dxf ent 0)
    )
    (cond 
      ((= name "3DFACE")
       (setq lst (list "[3D face]" laynm))
      )
      ((= name "3DSOLID")
       (setq lst (list "[3DSOLID]" 
                       laynm
                       (strcat "Version Number: " (itoa (dxf ent 70)))
                 )
       )
      )
      ((= name "ACAD_PROXY_ENTITY")
       (setq lst (list "[Proxy Entity]" laynm))
      )
      ((= name "ARC")
       (Setq Cen (VLAX-SafeArray->List (VLAX-Variant-Value (VLA-Get-Center obj))))
       (Setq arc_x (car Cen))
       (setq arc_y (nth 1 Cen))
       (setq lst (list "[ARC]" 
                       laynm
                       (strcat "Radius: " (rtos (vla-get-radius obj) 2 4))
                       (strcat "Center Angle:" 
                               (rtos (toang (vla-get-TotalAngle obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "Starting angle:" 
                               (rtos (toang (vla-get-StartAngle obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "End angle:" 
                               (rtos (toang (vla-get-EndAngle obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "Total Arc Length: " 
                               (rtos (vla-get-ArcLength obj) 2 4)
                       )
                       (strcat "Area: " (rtos (/ (vla-get-area obj)) 2 3) "")
                       (strcat "Center of circle: X=" (rtos arc_x))
                       (strcat "     Y=" (rtos arc_y))
                 )
       )
      )
      ((= name "ATTDEF")
       (setq lst (list "[Attribute Definition]" 
                       laynm
                       (strcat "Tag: " (vla-get-TagString obj))
                       (strcat "Prompt: " (vla-get-PromptString obj))
                       (strcat "Default: " (vla-get-TextString obj))
                       (strcat "Height: " (rtos (vla-get-Height obj) 2 3))
                       (strcat "Rotation: " 
                               (rtos (toang (vla-get-Rotation obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "Style: " (vla-get-StyleName obj))
                 )
       )
      )
      ((= name "ATTRIB")
       (setq lst (list "[Attribute]" 
                       laynm
                       (strcat "Tag: " (vla-get-TagString obj))
                       (strcat "Value: " (vla-get-TextString obj))
                       (strcat "Height: " (rtos (vla-get-Height obj) 2 3))
                       (strcat "Rotation: " 
                               (rtos (toang (vla-get-Rotation obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "Style: " (vla-get-StyleName obj))
                 )
       )
      )
      ((= name "BODY")
       (setq lst (list "[BODY]" 
                       laynm
                       (strcat "Version Number: " (itoa (dxf ent 70)))
                 )
       )
      )
      ((= name "CIRCLE")
       (Setq Cen (VLAX-SafeArray->List (VLAX-Variant-Value (VLA-Get-Center obj))))
       (Setq Cen_x (car Cen))
       (setq Cen_y (nth 1 Cen))
       (setq lst (list "[Circle]" 
                       laynm
                       (strcat "Radius: " (rtos (vla-get-radius obj) 2 3))
                       (strcat "Diameter: " (rtos (vla-get-diameter obj) 2 3))
                       (strcat "Circumference: " 
                               (rtos (vla-get-Circumference obj) 2 3)
                       )
                       (strcat "Area: " (rtos (/ (vla-get-Area obj)) 2 2) "  ")
                       (strcat "Center Point :X=" (rtos Cen_x))
                       (strcat "     Y=" (rtos Cen_y))
                 )
       )
      )
      ((= name "DIMENSION")
       (setq lst (list "[Dimension]" 
                       laynm
                       (strcat "Dimension Style: " (vla-get-StyleName obj))
                       (strcat "Text Style: " (vla-get-TextStyle obj))
                       (strcat "Text Height: " (rtos (vla-get-TextHeight obj) 2 3))
                       (strcat "Override Text: " 
                               (if (= (dxf ent 1) "") "None" (dxf ent 1))
                       )
                 )
       )
      )
      ((= name "ELLIPSE")
       (setq lst (list "[ELLIPSE]" 
                       laynm
                       (strcat "Major Radius: " 
                               (rtos (vla-get-MajorRadius obj) 2 3)
                       )
                       (strcat "Minor Radius: " 
                               (rtos (vla-get-MinorRadius obj) 2 3)
                       )
                       (strcat "Start Angle: " 
                               (rtos (toang (vla-get-StartAngle obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "End Angle: " 
                               (rtos (toang (vla-get-EndAngle obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "Area: " (rtos (/ (vla-get-Area obj)) 2 4) "  ")
                 )
       )
      )
      ((= name "HATCH")
       (setq lst (list "[Hatch]" 
                       laynm
                       (strcat "Pattern Name: " (vla-get-PatternName obj))
                       (strcat "Angle: " 
                               (rtos (toang (vla-get-PatternAngle obj) 1) 2 1)
                       )
                       (strcat "Scale: " (rtos (vla-get-PatternScale obj) 2 4))
                       (strcat "Associative: " 
                               (if (= (vla-get-AssociativeHatch obj) :vlax-false) 
                                 "Off"
                                 "On"
                               )
                       )
                       (strcat "Hatch Style: " 
                               (nth (vla-get-HatchStyle obj) 
                                    '("Normal" "Outer" "Ignore")
                               )
                       )
                 )
       )
      )
      ((= name "IMAGE")
       (setq lst (list "[Image]" 
                       laynm
                       (strcat "Image Size: " 
                               (rtos (car (dxf ent 13)) 2 0)
                               "X"
                               (rtos (cadr (dxf ent 13)) 2 0)
                       )
                 )
       )
       (strcat "Reference Path: " (vl-filename-base (dxf ent 1)))
      )
      ((= name "INSERT")
       (setq lst (list "[Block Reference]" 
                       laynm
                       (strcat "Name: " (dxf ent 2))
                       (strcat "X Scale: " (rtos (dxf ent 41) 2 1))
                       (strcat "Y Scale: " (rtos (dxf ent 42) 2 1))
                       (strcat "Z Scale: " (rtos (dxf ent 43) 2 1))
                       (strcat "Rotation: " 
                               (rtos (toang (vla-get-Rotation obj) 1) 2 1)
                               "Degree"
                       )
                 )
       )
      )
      ((= name "LEADER")
       (setq lst (list "[Leader]" 
                       laynm
                       (strcat "Style: " (vla-get-StyleName obj))
                       (strcat "Curver Type:" 
                               (dxf 
                                 (list (cons 0 "Polyline") (cons 1 "Spline"))
                                 (dxf ent 72)
                               )
                       )
                 )
       )
      )
      ((= name "LINE")
       (Setq Star (VLAX-SafeArray->List (VLAX-Variant-Value (VLA-Get-startpoint obj))))
       (Setq Star_x (car Star))
       (setq Star_y (nth 1 Star))
       (Setq End (VLAX-SafeArray->List (VLAX-Variant-Value (VLA-Get-endpoint obj))))
       (Setq End_x (car End))
       (setq End_y (nth 1 End))
       (setq lst (list "[Line]" 
                       laynm
                       (strcat "Length: " 
                               (rtos (vla-get-length obj) 2 4)
                               " Angle: "
                               (rtos (toang (vla-get-angle obj) 1) 2 3)
                               "Degree"
                       )
                       (strcat "Starting point: X=" 
                               (rtos Star_x)
                               " Y="
                               (rtos Star_y)
                       )
                       (strcat "End point: X=" (rtos End_x) " Y=" (rtos End_y))
                 )
       )
      )
      ((= name "LWPOLYLINE")
       (setq lst (list "[Lightweight Polyline]" 
                       laynm
                       (strcat "Constant width: " 
                               (if (dxf ent 43) 
                                 (rtos (vla-get-ConstantWidth obj) 2 4)
                                 "Wider Degree"
                               )
                       )
                       (strcat "Closed: " 
                               (if (= (vla-get-Closed obj) :vlax-false) 
                                 "No"
                                 "Yes"
                               )
                       )
                       (strcat "Area: " (rtos (/ (vla-get-Area obj)) 2 4) "  ")
                       (strcat "Length: " 
                               (rtos (vla-get-length obj) 2 4)
                       )
                 )
       )
      )

      ((= name "MTEXT")
       (setq lst (list "[MText]" 
                       laynm
                       (strcat "Height: " (rtos (vla-get-Height obj) 2 3))
                       (strcat "Rotation: " 
                               (rtos (toang (vla-get-Rotation obj) 1) 2 2)
                               "Degree"
                       )
                       (strcat "Style name: " (vla-get-StyleName obj))
                 )
       )
      )
      ((or (= name "OLEFRame") (= name "OLE2FRame"))
       (setq lst (list "[OLE border]" 
                       laynm
                       (strcat "Version number:" (itoa (dxf ent 70)))
                 )
       )
      )
      ((= name "POINT")
       (setq lst (list "[Point]" laynm))
      )
      ((= name "POLYLINE")
       (setq lst (list "[Polyline]" laynm))
      )
      ((= name "RAY")
       (setq lst (list "[Ray]" laynm))
      )
      ; ((= name "REGION")
      ;  (setq lst (list "[Region]" laynm (strcat "格式版本号:" (itoa (dxf ent 70)))))
      ;)
      ((= name "REGION")
       (setq lst (list "[Region]" 
                       laynm
                       (strcat "Area: " (rtos (vla-get-Area obj) 2 2))
                 )
       )
       (setq lst (list "[Region]" 
                       laynm
                       (strcat "Version number:" (itoa (dxf ent 70)))
                 )
       )
      )
      ((= name "SHAPE")
       (setq lst (list "[SHAPE]" 
                       laynm
                       (strcat "'Height: " (rtos (vla-get-Height obj) 2 3))
                       (strcat "'Scale Factor: " 
                               (rtos (vla-get-ScaleFactor obj) 2 3)
                       )
                       (strcat "'Rotation" 
                               (rtos (toang (vla-get-Rotation obj) 1) 2 4)
                               "Degree"
                       )
                 )
       )
      )
      ((= name "SOLID")
       (setq lst (list "[Solid]" laynm))
      )
      ((= name "SPLINE")
       (setq lst (list "[Spline]" 
                       laynm
                       (strcat "Closed: " 
                               (if (= (vla-get-Closed obj) :vlax-false) "Off" "On")
                       )
                       (strcat "'Rotation: " (rtos (vla-get-Degree obj) 2 0))
                       (strcat "'Area: " (rtos (/ (vla-get-Area obj)) 2 2) "  ")
                 )
       )
      )
      ((= name "TEXT")
       (setq lst (list "[TEXT]" 
                       laynm
                       (strcat "Text String : " (vla-get-TextString obj))
                       (strcat "Height: " (rtos (vla-get-Height obj) 2 3))
                       (strcat "'Scale Factor: " 
                               (rtos (vla-get-ScaleFactor obj) 2 3)
                       )
                       (strcat "'Rotation" 
                               (rtos (toang (vla-get-Rotation obj) 1) 2 4)
                               "Degree"
                       )
                       (strcat "'Style Name: " (vla-get-StyleName obj))
                       (strcat "Alignment: " 
                               (nth (vla-get-Alignment obj) 
                                    '("Left" "Center" "Right" "Aligned" "Middle" 
                                      "Fit" "TopLeft" "TopCenter" "TopRight" 
                                      "MiddleLeft" "MiddleCenter" "MiddleRight" 
                                      "BottomLeft" "BottomCenter" "BottomRight"
                                     )
                               )
                       )
                 )
       )
      )
      ((= name "TOLERANCE")
       (setq lst (list "[TOLERANCE]" 
                       laynm
                       (strcat "Style Name: " (vla-get-StyleName obj))
                       (strcat "Text Style: " (vla-get-TextStyle obj))
                       (strcat "Text 'Height: " 
                               (rtos (vla-get-TextHeight obj) 2 3)
                       )
                 )
       )
      )
      ((= name "TRACE")
       (setq lst (list "[TRACE]" laynm))
      )
      ((= name "XLINE")
       (setq lst (list "[Construction line]" laynm))
      )
      (T
       (setq lst (list "[Unknown object]" laynm))
      )
    )
    (setq ss (ssadd)
          h  (/ (getvar "viewsize") 50)
    )
    (setq ang (fx (angle (getvar "viewctr") pt)))
    (setq n (* 1.4 (1+ (/ (apply 'max (mapcar 'strlen lst)) 2.0))))
    (ssadd 
      (add_solid 
        pt
        (polar pt (car ang) (* n h))
        (setq pt (polar pt (cadr ang) (+ h (* 1.8 h (length lst)))))
        (polar pt (car ang) (* n h))
      )
      ss
    )
    (setq pt (polar pt (car ang) (/ (* n h) 2)))
    (if (= (caddr ang) 0) 
      (setq pt (polar pt (/ pi 2) (* 0.4 h)))
      (setq pt (polar pt (/ pi 2) (+ (* 1.4 h) (* 1.8 h (length lst)))))
    )
    (setq n -1)
    (repeat (length lst) 
      (ssadd 
        (add_text 
          (setq pt (polar pt (+ pi (/ pi 2)) (* 1.8 h)))
          h
          0
          (nth (setq n (1+ n)) lst)
          "Iso"
          1
        )
        ss
      )
    )
  )
  (vl-load-com)
  (command "_.undo" "_m")
  (prompt "\n***Move the mouse over the object to view it!")
  (setq olderr  *error*
        *error* myerr
  )
  (setq oldos (getvar "osmode"))
  (setq oldfill (getvar "fillmode"))
  (setvar "osmode" 0)
  (setvar "fillmode" 1)
  (setvar "cmdecho" 0)
  (if (not (tblsearch "style" "Iso")) 
    (command "-STYLE" "Iso" "isocp.shx" "" "0.8" "" "" "")
  )
  (setq ss (ssadd))
  (while (not pd) 
    (while 
      (not 
        (progn 
          (setq gr (grread T 1))
          (if (= (car gr) 5) 
            (setq pt  (cadr gr)
                  ent (nentselp pt)
                  ent (if (and ent (= (type (last (last ent))) 'ename)) 
                        (last (last ent))
                        (car ent)
                      )
            )
            (setq pd T)
          )
        )
      )
    )
    (if (and (not pd) (not (equal ent entold)) (not (ssmemb ent ss))) 
      (progn 
        (if entold (redraw entold 4))
        (if ss (command "_.erase" ss ""))
        (redraw ent 3)
        (dis ent)
        (setq entold ent)
      )
    )
  )
  (if entold (redraw entold 4))
  (if ss (command "_.erase" ss ""))
  (setvar "osmode" oldos)
  (setvar "fillmode" oldfill)
  (setq *error* olderr)
  (princ)
)

(princ) 