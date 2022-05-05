    const State = {
        Running: "running",
        Stop: "stop",
        Error: "error",
    }
    Object.freeze(State);

    class CurTotal {

        constructor(current, total) {
            this.current = current;
            this.total = total;
        }

        get percent() {
            if (this.total === 0) {
                return 0;
            }
            return toFixed(this.current / this.total * 100, 2);
        }

        get color() {
            const percent = this.percent;
            if (percent < 80) {
                return '#67C23A';
            } else if (percent < 90) {
                return '#E6A23C';
            } else {
                return '#F56C6C';
            }
        }
    }

    class Status {
        constructor(data) {
            this.cpu = new CurTotal(0, 0);
            this.disk = new CurTotal(0, 0);
            this.loads = [0, 0, 0];
            this.mem = new CurTotal(0, 0);
            this.netIO = {up: 0, down: 0};
            this.netTraffic = {sent: 0, recv: 0};
            this.swap = new CurTotal(0, 0);
            this.tcpCount = 0;
            this.udpCount = 0;
            this.uptime = 0;
            this.xray = {state: State.Stop, errorMsg: "", version: "", color: ""};

            if (data == null) {
                return;
            }
            this.cpu = new CurTotal(data.cpu, 100);
            this.disk = new CurTotal(data.disk.current, data.disk.total);
            this.loads = data.loads.map(load => toFixed(load, 2));
            this.mem = new CurTotal(data.mem.current, data.mem.total);
            this.netIO = data.netIO;
            this.netTraffic = data.netTraffic;
            this.swap = new CurTotal(data.swap.current, data.swap.total);
            this.tcpCount = data.tcpCount;
            this.udpCount = data.udpCount;
            this.uptime = data.uptime;
            this.xray = data.xray;
            switch (this.xray.state) {
                case State.Running:
                    this.xray.color = "green";
                    break;
                case State.Stop:
                    this.xray.color = "orange";
                    break;
                case State.Error:
                    this.xray.color = "red";
                    break;
                default:
                    this.xray.color = "gray";
            }
        }
    }

    const versionModal = {
        visible: false,
        versions: [],
        show(versions) {
            this.visible = true;
            this.versions = versions;
        },
        hide() {
            this.visible = false;
        },
    };

    const app = new Vue({
        delimiters: ['[[', ']]'],
        el: '#app',
        data: {
            siderDrawer,
            status: new Status(),
            versionModal,
            spinning: false,
            loadingTip: 'Đang tải',
        },
        methods: {
            loading(spinning, tip = 'Đang tải') {
                this.spinning = spinning;
                this.loadingTip = tip;
            },
            async getStatus() {
                const msg = await HttpUtil.post('/server/status');
                if (msg.success) {
                    this.setStatus(msg.obj);
                }
            },
            setStatus(data) {
                this.status = new Status(data);
            },
            async openSelectV2rayVersion() {
                this.loading(true);
                const msg = await HttpUtil.post('server/getXrayVersion');
                this.loading(false);
                if (!msg.success) {
                    return;
                }
                versionModal.show(msg.obj);
            },
            switchV2rayVersion(version) {
                this.$confirm({
                    title: 'Chuyển phiên bản xray',
                    content: 'Có chuyển phiên bản xray sang không' + ` ${version}?`,
                    okText: 'Đảm bảo',
                    cancelText: 'Hủy bỏ',
                    onOk: async () => {
                        versionModal.hide();
                        this.loading(true, 'Trong quá trình cài đặt, vui lòng không làm mới trang này');
                        await HttpUtil.post(`/server/installXray/${version}`);
                        this.loading(false);
                    },
                });
            },
        },
        async mounted() {
            while (true) {
                try {
                    await this.getStatus();
                } catch (e) {
                    console.error(e);
                }
                await PromiseUtil.sleep(2000);
            }
        },
    });
