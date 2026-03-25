//
//  NotificationManager.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 12/3/25.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error requesting notification permission: \(error)")
                }
                completion(granted)
            }
        }
    }
    
    func scheduleNotifications(for profile: UserProfile) {
        // First, cancel existing notifications
        cancelNotifications()
        
        guard profile.notificationsEnabled else { return }
        
        // Check permission status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("Notifications not authorized")
                return
            }
            
            self.schedule(for: profile)
        }
    }
    
    private func schedule(for profile: UserProfile) {
        let content = UNMutableNotificationContent()
        content.title = "Time for Reflection"
        content.body = "Take a moment to pause and reflect on your day."
        content.sound = .default
        
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: profile.notificationTime)
        
        // Determine trigger based on frequency
        // For MVP, we'll schedule a repeating daily notification if daily,
        // or weekly if weekly. "As Needed" implies no scheduled reminders?
        // Or maybe we just use the time of day.
        
        // Let's assume:
        // Daily -> Every day at time
        // Weekly -> Every week on Sunday? Or just pick a day? 
        // For simplicity, let's just use Daily for now if frequency is Daily.
        // If Weekly, maybe we need a day picker? For now, let's default to Sunday if Weekly.
        
        switch profile.examenFrequency {
        case .daily:
            // Repeat every day
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "daily-examen", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
            
        case .weekly:
            // Repeat every week (Sunday)
            dateComponents.weekday = 1 // Sunday
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "weekly-examen", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
            
        case .asNeeded:
            // No automatic schedule
            break
        }
    }
    
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
