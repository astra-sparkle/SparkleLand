import QtQuick
import org.kde.plasma.plasma5support as P5Support

// 媒体实现候选 2（兜底）：plasma5support 的 mpris2 dataengine。
//
// 该引擎没有正式文档，所以这里**不写死 source / key 名称**：运行时枚举引擎给出的
// source 及其键，按名字片段挑选，并把现场数据打进日志，便于按真实环境修正。
// （DataSource 的属性 data / connectedSources / sources / valid 已对照本机
//   plasma5supportplugin.qmltypes 核实。）
QtObject {
    id: root

    readonly property var dataSource: P5Support.DataSource {
        connectedSources: ["players"]
        engine: "mpris2"
    }

    // 不假定 source 叫什么，取第一个有内容的
    readonly property var entry: {
        const all = root.dataSource.data || ({});
        const sources = Object.keys(all);
        for (let i = 0; i < sources.length; ++i) {
            const value = all[sources[i]];
            if (value && Object.keys(value).length > 0) {
                return value;
            }
        }
        return null;
    }

    readonly property var keys: root.entry ? Object.keys(root.entry) : []

    // 按名字片段找键：兼容 track / Title / Metadata / PlaybackStatus 等各种命名
    function pick(fragments, accept) {
        for (let f = 0; f < fragments.length; ++f) {
            for (let k = 0; k < root.keys.length; ++k) {
                if (root.keys[k].toLowerCase().indexOf(fragments[f]) < 0) {
                    continue;
                }

                const value = root.entry[root.keys[k]];
                if (accept(value)) {
                    return value;
                }
            }
        }
        return undefined;
    }

    readonly property string trackTitle: {
        const value = root.pick(["track", "title"], function(v) {
            return typeof v === "string" && v.length > 0;
        });
        return typeof value === "string" ? value : "";
    }

    readonly property bool playing: {
        const value = root.pick(["status", "state"], function(v) {
            return typeof v === "string" || typeof v === "boolean";
        });
        if (typeof value === "boolean") {
            return value;
        }
        return typeof value === "string" ? value.toLowerCase() === "playing" : false;
    }

    // 诊断：这条路径无文档，把现场数据打出来便于修正 source / key 约定
    Component.onCompleted: console.info("Sparkle Land: mpris2 dataengine valid =", root.dataSource.valid,
                                        "sources =", root.dataSource.sources,
                                        "data 中的 source =", Object.keys(root.dataSource.data || ({})),
                                        "keys =", root.keys)
}
