(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-status (err u104))

(define-map events
  { event-id: uint }
  {
    event-name: (string-ascii 100),
    client: principal,
    event-date: uint,
    venue: (string-ascii 100),
    total-budget: uint,
    spent-budget: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map vendors
  { event-id: uint, vendor-id: uint }
  {
    vendor-name: (string-ascii 100),
    vendor-contact: principal,
    service-type: (string-ascii 50),
    contract-amount: uint,
    payment-status: (string-ascii 20),
    delivery-date: uint,
    performance-rating: uint
  }
)

(define-map client-communications
  { event-id: uint, communication-id: uint }
  {
    message-type: (string-ascii 30),
    subject: (string-ascii 100),
    content-hash: (string-ascii 64),
    timestamp: uint,
    status: (string-ascii 20),
    requires-response: bool
  }
)

(define-map logistics-tasks
  { event-id: uint, task-id: uint }
  {
    task-name: (string-ascii 100),
    assigned-to: principal,
    due-date: uint,
    completion-status: (string-ascii 20),
    priority: (string-ascii 10),
    completion-date: (optional uint)
  }
)

(define-map performance-metrics
  { event-id: uint }
  {
    budget-variance: int,
    on-time-completion: bool,
    client-satisfaction: uint,
    vendor-performance-avg: uint,
    tasks-completed-on-time: uint,
    total-tasks: uint
  }
)

(define-data-var next-event-id uint u1)
(define-data-var next-vendor-id uint u1)
(define-data-var next-communication-id uint u1)
(define-data-var next-task-id uint u1)

(define-public (create-event
  (event-name (string-ascii 100))
  (client principal)
  (event-date uint)
  (venue (string-ascii 100))
  (total-budget uint)
)
  (let
    (
      (event-id (var-get next-event-id))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set events
      { event-id: event-id }
      {
        event-name: event-name,
        client: client,
        event-date: event-date,
        venue: venue,
        total-budget: total-budget,
        spent-budget: u0,
        status: "planning",
        created-at: stacks-block-height
      }
    )
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

(define-public (add-vendor
  (event-id uint)
  (vendor-name (string-ascii 100))
  (vendor-contact principal)
  (service-type (string-ascii 50))
  (contract-amount uint)
  (delivery-date uint)
)
  (let
    (
      (vendor-id (var-get next-vendor-id))
      (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set vendors
      { event-id: event-id, vendor-id: vendor-id }
      {
        vendor-name: vendor-name,
        vendor-contact: vendor-contact,
        service-type: service-type,
        contract-amount: contract-amount,
        payment-status: "pending",
        delivery-date: delivery-date,
        performance-rating: u0
      }
    )
    (map-set events
      { event-id: event-id }
      (merge event { spent-budget: (+ (get spent-budget event) contract-amount) })
    )
    (var-set next-vendor-id (+ vendor-id u1))
    (ok vendor-id)
  )
)

(define-public (record-client-communication
  (event-id uint)
  (message-type (string-ascii 30))
  (subject (string-ascii 100))
  (content-hash (string-ascii 64))
  (requires-response bool)
)
  (let
    (
      (communication-id (var-get next-communication-id))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? events { event-id: event-id })) err-not-found)
    (map-set client-communications
      { event-id: event-id, communication-id: communication-id }
      {
        message-type: message-type,
        subject: subject,
        content-hash: content-hash,
        timestamp: stacks-block-height,
        status: "sent",
        requires-response: requires-response
      }
    )
    (var-set next-communication-id (+ communication-id u1))
    (ok communication-id)
  )
)

(define-public (create-logistics-task
  (event-id uint)
  (task-name (string-ascii 100))
  (assigned-to principal)
  (due-date uint)
  (priority (string-ascii 10))
)
  (let
    (
      (task-id (var-get next-task-id))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? events { event-id: event-id })) err-not-found)
    (map-set logistics-tasks
      { event-id: event-id, task-id: task-id }
      {
        task-name: task-name,
        assigned-to: assigned-to,
        due-date: due-date,
        completion-status: "pending",
        priority: priority,
        completion-date: none
      }
    )
    (var-set next-task-id (+ task-id u1))
    (ok task-id)
  )
)

(define-public (complete-task
  (event-id uint)
  (task-id uint)
)
  (let
    (
      (task (unwrap! (map-get? logistics-tasks { event-id: event-id, task-id: task-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set logistics-tasks
      { event-id: event-id, task-id: task-id }
      (merge task {
        completion-status: "completed",
        completion-date: (some stacks-block-height)
      })
    )
    (ok true)
  )
)

(define-public (update-vendor-performance
  (event-id uint)
  (vendor-id uint)
  (performance-rating uint)
  (payment-status (string-ascii 20))
)
  (let
    (
      (vendor (unwrap! (map-get? vendors { event-id: event-id, vendor-id: vendor-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= performance-rating u100) err-invalid-status)
    (map-set vendors
      { event-id: event-id, vendor-id: vendor-id }
      (merge vendor {
        performance-rating: performance-rating,
        payment-status: payment-status
      })
    )
    (ok true)
  )
)

(define-public (record-performance-metrics
  (event-id uint)
  (budget-variance int)
  (on-time-completion bool)
  (client-satisfaction uint)
  (tasks-completed-on-time uint)
  (total-tasks uint)
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? events { event-id: event-id })) err-not-found)
    (asserts! (<= client-satisfaction u100) err-invalid-status)
    (map-set performance-metrics
      { event-id: event-id }
      {
        budget-variance: budget-variance,
        on-time-completion: on-time-completion,
        client-satisfaction: client-satisfaction,
        vendor-performance-avg: u0,
        tasks-completed-on-time: tasks-completed-on-time,
        total-tasks: total-tasks
      }
    )
    (ok true)
  )
)

(define-public (update-event-status
  (event-id uint)
  (new-status (string-ascii 20))
)
  (let
    (
      (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set events
      { event-id: event-id }
      (merge event { status: new-status })
    )
    (ok true)
  )
)

(define-read-only (get-event (event-id uint))
  (map-get? events { event-id: event-id })
)

(define-read-only (get-vendor (event-id uint) (vendor-id uint))
  (map-get? vendors { event-id: event-id, vendor-id: vendor-id })
)

(define-read-only (get-client-communication (event-id uint) (communication-id uint))
  (map-get? client-communications { event-id: event-id, communication-id: communication-id })
)

(define-read-only (get-logistics-task (event-id uint) (task-id uint))
  (map-get? logistics-tasks { event-id: event-id, task-id: task-id })
)

(define-read-only (get-performance-metrics (event-id uint))
  (map-get? performance-metrics { event-id: event-id })
)

(define-read-only (get-event-budget-status (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (ok {
      total-budget: (get total-budget event),
      spent-budget: (get spent-budget event),
      remaining-budget: (- (get total-budget event) (get spent-budget event))
    })
    err-not-found
  )
)

(define-read-only (get-next-event-id)
  (var-get next-event-id)
)


;; title: event-coordinator
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

