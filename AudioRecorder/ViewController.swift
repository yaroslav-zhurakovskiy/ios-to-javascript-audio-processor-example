//
//  ViewController.swift
//  AudioRecorder
//
//  Created by Yaroslav Zhurakovskiy on 05.05.2020.
//  Copyright © 2020 Yaroslav Zhurakovskiy. All rights reserved.
//

import UIKit
import AVFoundation
import JavaScriptCore

class ViewController: UIViewController, AVAudioRecorderDelegate {
    @IBOutlet weak var recordAudioButton: UIButton!
    @IBOutlet weak var playAudioButton: UIButton!
    @IBOutlet weak var processAudioButton: UIButton!
    
    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer: AVAudioPlayer!
    
    private var jsContext: JSContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupJavascript() // Setup javascript functions, exception handling and so on.
    }
    
    private func setupJavascript() {
        jsContext = JSContext()
        jsContext.exceptionHandler = { _, exception in
            print("Caught JS excepton: \(exception!)")
        }
        
        // __swift_log native implementation
        let logFunctionImplementation: @convention (block) (JSValue) -> Void = { value in
            if value.isObject, let dictionaryRepresentation = value.toDictionary() {
                print(dictionaryRepresentation)
            } else {
                print(value)
            }
        }
        let opaqueType = unsafeBitCast(logFunctionImplementation, to: AnyObject.self)
        jsContext.setObject(opaqueType, forKeyedSubscript: "__swift_log" as NSString)
        
        // Declare console.log and processAudio
        jsContext.evaluateScript("""
            var console = {
                log: function(data) { __swift_log(data); }
            };

            // Prints each byte as a hex value
            function processAudio(bytes) {
                var hexString = ""
                for(var index = 0; index < bytes.length; index++) {
                    var byte = bytes.getByte(index);
                    hexString += "0x" + byte.toString(16);
                }
                console.log(hexString)
            }
        """)
    }
    
    @IBAction func askForPermissions() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                // UI related work has to be executed on main thread(queue)
                DispatchQueue.main.async {
                    if allowed {
                        self.recordAudioButton.isEnabled = true
                        self.playAudioButton.isEnabled = true
                        self.processAudioButton.isEnabled = true
                        print("User allowed recording")
                    } else {
                        print("User did not grant his permissions")
                    }
                }
            }
        } catch let error {
            presentError(withMessage: error.localizedDescription)
        }
    }
    
    @IBAction func playAudio() {
        let audioFileURL = recordingAudioFileURL()
        
        if FileManager.default.fileExists(atPath: audioFileURL.path) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
                audioPlayer.play()
            } catch let error {
                presentError(withMessage: error.localizedDescription)
            }
        } else {
            presentError(withMessage: "Audio file does not exist")
        }
    }
    
    private func presentError(withMessage message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    @IBAction func recordAudio() {
        if isRecording {
            finishRecording(successfully: true)
        } else {
            startRecording()
        }
    }
    
    private var isRecording: Bool {
        return audioRecorder != nil // If we've created an audio recorder it means we started recording
    }
    
    private func startRecording() {
        do {
            let audioFilename = recordingAudioFileURL()
            print("Saving audio file to", audioFilename)
            audioRecorder = try AVAudioRecorder(
                url: audioFilename,
                settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 12000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )
            audioRecorder.delegate = self
            audioRecorder.record()
            recordAudioButton.setTitle("Finish recording", for: .normal)
        } catch {
            finishRecording(successfully: false)
        }
    }
    
    private func recordingAudioFileURL() -> URL {
         return getDocumentsDirectory().appendingPathComponent("recording.m4a")
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func finishRecording(successfully: Bool) {
        audioRecorder.stop()
        audioRecorder = nil
        
        if successfully {
            recordAudioButton.setTitle("Re-record audio", for: .normal)
        } else {
            recordAudioButton.setTitle("Record audio", for: .normal)
        }
    }
    
    @IBAction func processAudioFileWithJavascript() {
        let audioFileURL = recordingAudioFileURL()
        
        if FileManager.default.fileExists(atPath: audioFileURL.path) {
            do {
                //  Load audio file as blob
                let audioFileContent = try Data(contentsOf: audioFileURL)
                // Find processAudio js function
                let processAudio = jsContext.objectForKeyedSubscript("processAudio")!
                // Convert raw pointer to our ByteArray wrapper class
                let byteArray = ByteArray(data: audioFileContent)
                // Invoke js function with a byte array
                processAudio.call(withArguments: [byteArray])
            } catch let error {
                presentError(withMessage: error.localizedDescription)
            }
        } else {
            presentError(withMessage: "Audio file does not exist")
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully: Bool) {
        if !successfully {
            finishRecording(successfully: false)
        }
    }
}
