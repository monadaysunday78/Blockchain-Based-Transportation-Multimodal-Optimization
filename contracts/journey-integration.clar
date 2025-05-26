;; Journey Integration Contract
;; Coordinates multimodal trips and manages journey segments

;; Constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_JOURNEY_NOT_FOUND (err u201))
(define-constant ERR_INVALID_SEGMENT (err u202))
(define-constant ERR_JOURNEY_COMPLETED (err u203))

;; Data Variables
(define-data-var next-journey-id uint u1)

;; Data Maps
(define-map journeys
  { journey-id: uint }
  {
    user: principal,
    origin: (string-ascii 100),
    destination: (string-ascii 100),
    status: (string-ascii 20),
    total-cost: uint,
    total-duration: uint,
    created-at: uint,
    completed-at: (optional uint)
  }
)

(define-map journey-segments
  { journey-id: uint, segment-index: uint }
  {
    provider-id: uint,
    transport-type: (string-ascii 50),
    start-location: (string-ascii 100),
    end-location: (string-ascii 100),
    cost: uint,
    duration: uint,
    status: (string-ascii 20)
  }
)

(define-map user-journeys
  { user: principal, journey-index: uint }
  { journey-id: uint }
)

(define-map journey-segment-count
  { journey-id: uint }
  { count: uint }
)

;; Public Functions

;; Create a new journey
(define-public (create-journey (origin (string-ascii 100))
                              (destination (string-ascii 100)))
  (let ((journey-id (var-get next-journey-id))
        (user tx-sender))

    (map-set journeys
      { journey-id: journey-id }
      {
        user: user,
        origin: origin,
        destination: destination,
        status: "planning",
        total-cost: u0,
        total-duration: u0,
        created-at: block-height,
        completed-at: none
      }
    )

    (map-set journey-segment-count
      { journey-id: journey-id }
      { count: u0 }
    )

    (var-set next-journey-id (+ journey-id u1))
    (ok journey-id)
  )
)

;; Add a segment to a journey
(define-public (add-journey-segment (journey-id uint)
                                   (provider-id uint)
                                   (transport-type (string-ascii 50))
                                   (start-location (string-ascii 100))
                                   (end-location (string-ascii 100))
                                   (cost uint)
                                   (duration uint))
  (let ((segment-count-data (unwrap! (map-get? journey-segment-count { journey-id: journey-id }) ERR_JOURNEY_NOT_FOUND))
        (current-count (get count segment-count-data))
        (journey-data (unwrap! (map-get? journeys { journey-id: journey-id }) ERR_JOURNEY_NOT_FOUND)))

    (asserts! (is-eq (get user journey-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status journey-data) "planning") ERR_JOURNEY_COMPLETED)

    (map-set journey-segments
      { journey-id: journey-id, segment-index: current-count }
      {
        provider-id: provider-id,
        transport-type: transport-type,
        start-location: start-location,
        end-location: end-location,
        cost: cost,
        duration: duration,
        status: "planned"
      }
    )

    (map-set journey-segment-count
      { journey-id: journey-id }
      { count: (+ current-count u1) }
    )

    ;; Update journey totals
    (map-set journeys
      { journey-id: journey-id }
      (merge journey-data {
        total-cost: (+ (get total-cost journey-data) cost),
        total-duration: (+ (get total-duration journey-data) duration)
      })
    )

    (ok current-count)
  )
)

;; Start a journey
(define-public (start-journey (journey-id uint))
  (let ((journey-data (unwrap! (map-get? journeys { journey-id: journey-id }) ERR_JOURNEY_NOT_FOUND)))
    (asserts! (is-eq (get user journey-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status journey-data) "planning") ERR_JOURNEY_COMPLETED)

    (map-set journeys
      { journey-id: journey-id }
      (merge journey-data { status: "in-progress" })
    )
    (ok true)
  )
)

;; Complete a journey
(define-public (complete-journey (journey-id uint))
  (let ((journey-data (unwrap! (map-get? journeys { journey-id: journey-id }) ERR_JOURNEY_NOT_FOUND)))
    (asserts! (is-eq (get user journey-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status journey-data) "in-progress") ERR_JOURNEY_COMPLETED)

    (map-set journeys
      { journey-id: journey-id }
      (merge journey-data {
        status: "completed",
        completed-at: (some block-height)
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get journey details
(define-read-only (get-journey (journey-id uint))
  (map-get? journeys { journey-id: journey-id })
)

;; Get journey segment
(define-read-only (get-journey-segment (journey-id uint) (segment-index uint))
  (map-get? journey-segments { journey-id: journey-id, segment-index: segment-index })
)

;; Get journey segment count
(define-read-only (get-segment-count (journey-id uint))
  (map-get? journey-segment-count { journey-id: journey-id })
)
