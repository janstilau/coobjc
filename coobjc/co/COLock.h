
#ifndef COLock_h
#define COLock_h

#define COOBJC_CONCAT(A, B)             COOBJC_CONCAT_(A, B)
#define COOBJC_CONCAT_(A, B)            A ## B

#define COOBJC_LOCK_TYPE                dispatch_semaphore_t
#define COOBJC_LOCK_DEF(LOCK)           dispatch_semaphore_t LOCK
#define COOBJC_LOCK_INIT(LOCK)          LOCK = dispatch_semaphore_create(1)
#define COOBJC_LOCK(LOCK)               dispatch_semaphore_wait(LOCK, DISPATCH_TIME_FOREVER)
#define COOBJC_UNLOCK(LOCK)             dispatch_semaphore_signal(LOCK)

static inline void COOBJC_unlock(COOBJC_LOCK_TYPE *lock) {
    COOBJC_UNLOCK(*lock);
}

#define COOBJC_SCOPELOCK(LOCK)          COOBJC_LOCK(LOCK); \
COOBJC_LOCK_TYPE COOBJC_CONCAT(auto_lock_, __LINE__) __attribute__((cleanup(COOBJC_unlock), unused)) = LOCK


#endif /* COLock_h */
