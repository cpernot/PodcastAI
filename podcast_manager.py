import sys
import os
import subprocess
import json
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTableWidget, QTableWidgetItem, QHeaderView,
    QFileDialog, QDialog, QListWidget, QListWidgetItem, QAbstractItemView,
    QProgressBar, QMessageBox
)
from PySide6.QtCore import Qt, QThread, Signal, QSize

class GCSWorker(QThread):
    finished = Signal(list)
    error = Signal(str)

    def run(self):
        try:
            # On Windows, gcloud is often a batch file or ps1. shell=True helps find it.
            cmd = ["gcloud", "storage", "ls", "--long", "gs://ai-g-course-podcast"]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True, shell=True)
            
            lines = result.stdout.strip().split('\n')
            files = []
            for line in lines:
                parts = line.split()
                # Expected format: [SIZE, DATETIME, URL]
                if len(parts) >= 3 and parts[0].isdigit():
                    size = int(parts[0])
                    updated = parts[1]
                    url = parts[2]
                    name = url.split('/')[-1]
                    files.append({
                        "name": name,
                        "size": size,
                        "updated": updated
                    })
            self.finished.emit(files)
        except subprocess.CalledProcessError as e:
            self.error.emit(f"Failed to fetch files: {e.stderr}")
        except Exception as e:
            self.error.emit(str(e))

class ReorderDialog(QDialog):
    def __init__(self, files, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Reorder Upload Items")
        self.setMinimumSize(400, 500)
        
        layout = QVBoxLayout(self)
        
        title = QLabel("Selected Items (Drag to Reorder)")
        title.setStyleSheet("font-weight: bold; font-size: 16px;")
        layout.addWidget(title)
        
        self.list_widget = QListWidget()
        self.list_widget.setDragDropMode(QAbstractItemView.InternalMove)
        self.list_widget.setSelectionMode(QAbstractItemView.SingleSelection)
        
        # Sort initial files by name as per requirement
        files.sort()
        
        for f in files:
            item = QListWidgetItem(os.path.basename(f))
            item.setData(Qt.UserRole, f) # Store full path
            self.list_widget.addItem(item)
            
        layout.addWidget(self.list_widget)
        
        btn_layout = QHBoxLayout()
        self.upload_btn = QPushButton("Confirm & Upload")
        self.cancel_btn = QPushButton("Cancel")
        self.cancel_btn.setObjectName("secondaryButton")
        
        self.upload_btn.clicked.connect(self.accept)
        self.cancel_btn.clicked.connect(self.reject)
        
        btn_layout.addWidget(self.cancel_btn)
        btn_layout.addWidget(self.upload_btn)
        layout.addLayout(btn_layout)

    def get_ordered_files(self):
        ordered = []
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            ordered.append(item.data(Qt.UserRole))
        return ordered

class UploadWorker(QThread):
    progress = Signal(int)
    status = Signal(str)
    finished = Signal(int, str) # count, error_summary

    def __init__(self, file_paths):
        super().__init__()
        self.file_paths = file_paths

    def run(self):
        success_count = 0
        errors = []
        
        for i, file_path in enumerate(self.file_paths):
            filename = os.path.basename(file_path)
            self.status.emit(f"Processing {filename}...")
            self.progress.emit(i)
            
            try:
                # Ensure file is in audio_files
                target_path = os.path.join(os.getcwd(), "audio_files", filename)
                if os.path.abspath(file_path) != os.path.abspath(target_path):
                    import shutil
                    shutil.copy2(file_path, target_path)

                # Call PowerShell script
                cmd = ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", "./deploy_podcast.ps1", "-targetFileName", filename]
                subprocess.run(cmd, check=True, capture_output=True, shell=True)
                success_count += 1
            except Exception as e:
                err_msg = str(e)
                if isinstance(e, subprocess.CalledProcessError):
                    err_msg = e.stderr.decode('utf-8', errors='replace')
                errors.append(f"{filename}: {err_msg}")
            
        self.progress.emit(len(self.file_paths))
        error_summary = "\n".join(errors) if errors else ""
        self.finished.emit(success_count, error_summary)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PodcastAI Manager")
        self.setMinimumSize(900, 600)
        self.upload_results_pending = None # Store results to show after refresh
        
        # Load styles
        if os.path.exists("style.qss"):
            with open("style.qss", "r") as f:
                self.setStyleSheet(f.read())
        
        self.setup_ui()
        self.refresh_files()

    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(20, 20, 20, 20)
        main_layout.setSpacing(15)

        # Header
        header_layout = QHBoxLayout()
        title_label = QLabel("Remote Episode Status")
        title_label.setObjectName("titleLabel")
        header_layout.addWidget(title_label)
        
        header_layout.addStretch()
        
        self.refresh_btn = QPushButton("Refresh List")
        self.refresh_btn.setObjectName("secondaryButton")
        self.refresh_btn.clicked.connect(self.refresh_files)
        header_layout.addWidget(self.refresh_btn)
        
        main_layout.addLayout(header_layout)

        # File Table
        self.table = QTableWidget()
        self.table.setColumnCount(3)
        self.table.setHorizontalHeaderLabels(["Filename", "Size", "Last Modified"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setAlternatingRowColors(True)
        main_layout.addWidget(self.table)

        # Footer Actions
        footer_layout = QHBoxLayout()
        
        self.open_xml_btn = QPushButton("Edit RSS Feed (XML)")
        self.open_xml_btn.setObjectName("secondaryButton")
        self.open_xml_btn.clicked.connect(self.on_open_xml_clicked)
        footer_layout.addWidget(self.open_xml_btn)
        
        footer_layout.addStretch()
        
        self.upload_new_btn = QPushButton("Upload New Content")
        self.upload_new_btn.setMinimumHeight(45)
        self.upload_new_btn.clicked.connect(self.on_upload_clicked)
        footer_layout.addWidget(self.upload_new_btn)
        
        main_layout.addLayout(footer_layout)

        # Progress section
        self.status_label = QLabel("")
        self.status_label.setStyleSheet("color: #03dac6; font-style: italic;")
        main_layout.addWidget(self.status_label)

        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        main_layout.addWidget(self.progress_bar)

    def refresh_files(self, show_msg_on_done=None):
        self.refresh_btn.setEnabled(False)
        self.refresh_btn.setText("Refreshing...")
        self.upload_results_pending = show_msg_on_done
        
        if not self.status_label.text():
            self.status_label.setText("Refreshing remote file list...")
            
        self.worker = GCSWorker()
        self.worker.finished.connect(self.update_table)
        self.worker.error.connect(self.on_worker_error)
        self.worker.start()

    def update_table(self, files):
        self.table.setRowCount(0)
        for i, f in enumerate(files):
            self.table.insertRow(i)
            self.table.setItem(i, 0, QTableWidgetItem(f["name"]))
            
            size_mb = f["size"] / (1024 * 1024)
            self.table.setItem(i, 1, QTableWidgetItem(f"{size_mb:.2f} MB"))
            self.table.setItem(i, 2, QTableWidgetItem(f["updated"]))
            
        self.refresh_btn.setEnabled(True)
        self.refresh_btn.setText("Refresh List")
        self.status_label.setText("")
        
        # If we just finished an upload, show the summary now
        if self.upload_results_pending:
            count, errors = self.upload_results_pending
            if errors:
                QMessageBox.warning(self, "Upload Completed with Errors", 
                                  f"Processed {count} files.\n\nErrors:\n{errors}")
            else:
                QMessageBox.information(self, "Success", f"Successfully uploaded {count} episodes.")
            self.upload_results_pending = None

    def on_worker_error(self, message):
        QMessageBox.critical(self, "Error", message)
        self.refresh_btn.setEnabled(True)
        self.refresh_btn.setText("Refresh List")

    def on_open_xml_clicked(self):
        xml_path = os.path.abspath("podcast7.xml")
        if os.path.exists(xml_path):
            os.startfile(xml_path)
        else:
            QMessageBox.warning(self, "Warning", "podcast7.xml not found.")

    def on_upload_clicked(self):
        # 1. Select files
        default_dir = os.path.join(os.getcwd(), "audio_files")
        if not os.path.exists(default_dir):
            default_dir = os.getcwd()
            
        file_paths, _ = QFileDialog.getOpenFileNames(
            self, "Select Content to Upload", default_dir, "Audio Files (*.m4a *.mp3);;All Files (*)"
        )
        
        if not file_paths:
            return

        # 2. Reorder
        dialog = ReorderDialog(file_paths, self)
        if dialog.exec() == QDialog.Accepted:
            ordered_files = dialog.get_ordered_files()
            self.start_upload_process(ordered_files)

    def start_upload_process(self, file_paths):
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, len(file_paths))
        self.progress_bar.setValue(0)
        self.upload_new_btn.setEnabled(False)
        self.status_label.setText("Starting upload process...")
        
        self.upload_worker = UploadWorker(file_paths)
        self.upload_worker.progress.connect(self.progress_bar.setValue)
        self.upload_worker.status.connect(self.status_label.setText)
        self.upload_worker.finished.connect(self.on_upload_finished)
        self.upload_worker.start()

    def on_upload_finished(self, count, errors):
        self.progress_bar.setVisible(False)
        self.upload_new_btn.setEnabled(True)
        self.status_label.setText("Upload complete. Refreshing list...")
        
        # Trigger refresh and pass the results to be shown AFTER refresh
        self.refresh_files(show_msg_on_done=(count, errors))

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
