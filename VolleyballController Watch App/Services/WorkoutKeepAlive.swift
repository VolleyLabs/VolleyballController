import Foundation
import HealthKit

/// Keeps the app and your WebSocket alive until `stop()` is called.
/// Works even when the display turns off.
final class WorkoutKeepAlive: NSObject, HKWorkoutSessionDelegate {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var isAuthorized = false
    
    /// Returns true if the workout session is currently active
    var isActive: Bool {
        return session?.state == .running
    }

    /// Call once, right after opening your WebSocket
    func start() {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }
        
        // Request HealthKit permissions for workout data
        let typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        let typesToRead: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        
        store.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                    return
                }
                
                if success {
                    print("HealthKit authorization granted")
                    self?.isAuthorized = true
                    self?.beginWorkout()
                } else {
                    print("HealthKit authorization denied - app may sleep during long sessions")
                    print("You can enable HealthKit permissions in Settings > Privacy & Security > Health")
                }
            }
        }
    }

    private func beginWorkout() {
        guard isAuthorized else {
            print("Cannot start workout - HealthKit not authorized")
            return
        }
        
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .other                   // generic workout

        do {
            let s = try HKWorkoutSession(healthStore: store, configuration: cfg)
            s.delegate = self
            
            // Prepare the session first
            s.prepare()
            
            // Wait a moment for preparation, then start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                let b = s.associatedWorkoutBuilder()
                b.dataSource = HKLiveWorkoutDataSource(healthStore: self.store, workoutConfiguration: cfg)
                
                // Begin collection before starting activity
                b.beginCollection(withStart: Date()) { [weak self] success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("Collection started successfully")
                            // Now start the actual workout session
                            s.startActivity(with: Date())
                            print("Workout session started successfully - app will stay active")
                        } else {
                            print("Failed to begin collection: \(error?.localizedDescription ?? "Unknown error")")
                            print("Continuing without workout session - app may sleep during long sessions")
                            // Don't clean up yet, try to start anyway
                            s.startActivity(with: Date())
                        }
                    }
                }
                
                self.session = s
                self.builder = b
            }
        } catch { 
            print("Workout start failed: \(error.localizedDescription)")
            print("App will continue without background persistence")
        }
    }

    /// Stop when you no longer need background time
    func stop() {
        guard let session = session else { return }
        
        print("Stopping workout session")
        session.end()
        
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            if let error = error {
                print("Error ending collection: \(error.localizedDescription)")
            } else {
                print("Workout session ended successfully")
            }
            
            DispatchQueue.main.async {
                self?.session = nil
                self?.builder = nil
            }
        }
    }

    // Cleanup if system ends the workout externally
    func workoutSession(_ s: HKWorkoutSession,
                        didChangeTo to: HKWorkoutSessionState,
                        from from: HKWorkoutSessionState,
                        date: Date) {
        print("Workout session state changed from \(from.rawValue) to \(to.rawValue)")
        
        switch to {
        case .ended:
            print("Workout session ended")
            session = nil
            builder = nil
        case .running:
            print("Workout session is running - app will stay active")
        case .paused:
            print("Workout session paused")
        case .stopped:
            print("Workout session stopped")
        case .notStarted:
            print("Workout session not started")
        case .prepared:
            print("Workout session prepared")
        @unknown default:
            print("Unknown workout session state: \(to.rawValue)")
        }
    }
    
    // Required delegate method
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
        session = nil
        builder = nil
    }
}