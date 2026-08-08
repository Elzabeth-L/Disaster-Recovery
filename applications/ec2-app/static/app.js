// VaultRix Tasks - Frontend JavaScript Logic
document.addEventListener("DOMContentLoaded", () => {
    let currentFilter = "all";
    let allTasks = [];

    // DOM Elements
    const createTaskForm = document.getElementById("createTaskForm");
    const tasksTableBody = document.getElementById("tasksTableBody");
    const btnRefreshDb = document.getElementById("btnRefreshDb");
    const filterBtns = document.querySelectorAll(".filter-btn");

    // Metrics DOM
    const metricTotal = document.getElementById("metricTotal");
    const metricCompleted = document.getElementById("metricCompleted");
    const metricPending = document.getElementById("metricPending");
    const metricDbState = document.getElementById("metricDbState");

    // DR Panel DOM
    const drHost = document.getElementById("drHost");
    const drName = document.getElementById("drName");
    const drStatus = document.getElementById("drStatus");
    const drTime = document.getElementById("drTime");
    const drCount = document.getElementById("drCount");

    // Status Badges DOM
    const dbStatusBadge = document.getElementById("dbStatusBadge");

    // Initialize Page
    loadStatus();
    loadTasks();

    // -------------------------------------------------------------------------
    // API Fetch Functions
    // -------------------------------------------------------------------------
    async function loadStatus() {
        try {
            const res = await fetch("/api/status");
            if (!res.ok) throw new Error("Status endpoint returned error");
            const data = await res.json();

            // Update DR Panel
            drHost.textContent = data.database_host || "N/A";
            drName.textContent = data.database_name || "N/A";
            drStatus.textContent = (data.database || "DISCONNECTED").toUpperCase();
            drTime.textContent = data.server_time || "N/A";
            drCount.textContent = data.task_count !== undefined ? data.task_count : "0";

            // Update Badges & Metrics
            if (data.database === "connected") {
                dbStatusBadge.innerHTML = `<span class="status-dot dot-green"></span> DB: Connected`;
                metricDbState.textContent = "Connected";
                metricDbState.className = "metric-value metric-success";
                drStatus.style.color = "#3fb950";
            } else {
                dbStatusBadge.innerHTML = `<span class="status-dot dot-red"></span> DB: Disconnected`;
                metricDbState.textContent = "Disconnected";
                metricDbState.className = "metric-value metric-warning";
                drStatus.style.color = "#f85149";
            }
        } catch (err) {
            console.error("Failed to load status:", err);
            dbStatusBadge.innerHTML = `<span class="status-dot dot-red"></span> DB: Error`;
            metricDbState.textContent = "Error";
            metricDbState.className = "metric-value metric-warning";
        }
    }

    async function loadTasks() {
        try {
            const res = await fetch("/api/tasks");
            if (!res.ok) {
                if (res.status === 503) {
                    tasksTableBody.innerHTML = `
                        <tr>
                            <td colspan="6" class="loading-cell" style="color: #f85149;">
                                ⚠️ Database is currently unreachable. Configure DB_SECRET_ARN or start RDS PostgreSQL.
                            </td>
                        </tr>`;
                    return;
                }
                throw new Error("Failed to fetch tasks");
            }

            allTasks = await res.json();
            updateMetrics(allTasks);
            renderTasks(allTasks);
        } catch (err) {
            console.error("Failed to load tasks:", err);
            tasksTableBody.innerHTML = `
                <tr>
                    <td colspan="6" class="loading-cell" style="color: #f85149;">
                        ⚠️ Unable to load tasks. Verify backend database service.
                    </td>
                </tr>`;
        }
    }

    // -------------------------------------------------------------------------
    // Render Functions
    // -------------------------------------------------------------------------
    function updateMetrics(tasks) {
        const total = tasks.length;
        const completed = tasks.filter(t => t.status === "completed").length;
        const pending = total - completed;

        metricTotal.textContent = total;
        metricCompleted.textContent = completed;
        metricPending.textContent = pending;
    }

    function renderTasks(tasks) {
        let filtered = tasks;
        if (currentFilter === "pending") {
            filtered = tasks.filter(t => t.status === "pending");
        } else if (currentFilter === "completed") {
            filtered = tasks.filter(t => t.status === "completed");
        }

        if (filtered.length === 0) {
            tasksTableBody.innerHTML = `
                <tr>
                    <td colspan="6" class="loading-cell">No tasks found in database. Create one above!</td>
                </tr>`;
            return;
        }

        tasksTableBody.innerHTML = filtered.map(t => `
            <tr>
                <td><strong>#${t.id}</strong></td>
                <td>
                    <div class="task-title">${escapeHtml(t.title)}</div>
                    ${t.description ? `<div class="task-desc">${escapeHtml(t.description)}</div>` : ''}
                </td>
                <td>
                    <span class="badge badge-prio-${t.priority}">
                        ${t.priority.toUpperCase()}
                    </span>
                </td>
                <td>
                    <span class="badge badge-status-${t.status}">
                        ${t.status.toUpperCase()}
                    </span>
                </td>
                <td>${t.created_at || 'N/A'}</td>
                <td>
                    ${t.status === 'pending' ? `
                        <button class="btn btn-sm btn-action-complete" onclick="completeTask(${t.id})">
                            ✓ Complete
                        </button>
                    ` : ''}
                    <button class="btn btn-sm btn-action-delete" onclick="deleteTask(${t.id})">
                        🗑 Delete
                    </button>
                </td>
            </tr>
        `).join("");
    }

    // -------------------------------------------------------------------------
    // Form & Action Handlers
    // -------------------------------------------------------------------------
    createTaskForm.addEventListener("submit", async (e) => {
        e.preventDefault();

        const title = document.getElementById("taskTitle").value.trim();
        const description = document.getElementById("taskDesc").value.trim();
        const priority = document.querySelector('input[name="priority"]:checked').value;

        if (!title) return;

        const btnSubmit = document.getElementById("btnSubmit");
        const btnSubmitText = document.getElementById("btnSubmitText");
        btnSubmit.disabled = true;
        btnSubmitText.textContent = "Creating...";

        try {
            const res = await fetch("/api/tasks", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ title, description, priority })
            });

            if (!res.ok) {
                const errData = await res.json();
                throw new Error(errData.error || "Failed to create task");
            }

            showToast("Task created successfully in PostgreSQL!", "success");
            createTaskForm.reset();
            document.querySelector('input[name="priority"][value="medium"]').checked = true;

            await loadTasks();
            await loadStatus();
        } catch (err) {
            console.error("Create task error:", err);
            showToast(err.message, "error");
        } finally {
            btnSubmit.disabled = false;
            btnSubmitText.textContent = "Create Task";
        }
    });

    // Make global for inline button onclick
    window.completeTask = async function(id) {
        try {
            const res = await fetch(`/api/tasks/${id}/complete`, { method: "PUT" });
            if (!res.ok) throw new Error("Failed to complete task");
            showToast(`Task #${id} marked as completed!`, "success");
            await loadTasks();
            await loadStatus();
        } catch (err) {
            showToast(err.message, "error");
        }
    };

    window.deleteTask = async function(id) {
        if (!confirm(`Are you sure you want to delete task #${id}?`)) return;

        try {
            const res = await fetch(`/api/tasks/${id}`, { method: "DELETE" });
            if (!res.ok) throw new Error("Failed to delete task");
            showToast(`Task #${id} deleted from database!`, "success");
            await loadTasks();
            await loadStatus();
        } catch (err) {
            showToast(err.message, "error");
        }
    };

    // DB Refresh Button
    btnRefreshDb.addEventListener("click", async () => {
        btnRefreshDb.disabled = true;
        btnRefreshDb.textContent = "Checking...";
        try {
            const res = await fetch("/api/db-check");
            const data = await res.json();

            if (res.ok && data.status === "connected") {
                showToast("PostgreSQL Database is Connected & Healthy!", "success");
            } else {
                showToast("Database connection check failed.", "error");
            }
            await loadStatus();
            await loadTasks();
        } catch (err) {
            showToast("Failed to communicate with DB check endpoint.", "error");
        } finally {
            btnRefreshDb.disabled = false;
            btnRefreshDb.textContent = "🔄 Refresh DB Status";
        }
    });

    // Filter Buttons
    filterBtns.forEach(btn => {
        btn.addEventListener("click", () => {
            filterBtns.forEach(b => b.classList.remove("active"));
            btn.classList.add("active");
            currentFilter = btn.dataset.filter;
            renderTasks(allTasks);
        });
    });

    // -------------------------------------------------------------------------
    // Utilities
    // -------------------------------------------------------------------------
    function showToast(message, type = "success") {
        const toast = document.getElementById("toast");
        toast.textContent = message;
        toast.className = `toast toast-${type}`;
        
        setTimeout(() => {
            toast.className = "toast hidden";
        }, 3500);
    }

    function escapeHtml(str) {
        if (!str) return '';
        return str.replace(/[&<>"']/g, function(m) {
            return {
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#039;'
            }[m];
        });
    }
});
