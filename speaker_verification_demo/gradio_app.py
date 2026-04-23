"""
说话人确认系统 Gradio Demo
2025年FPGA创新设计大赛——安路赛道
"""
import gradio as gr
import os
from speaker_verification import SpeakerVerificationSystem


def create_app(sv_system: SpeakerVerificationSystem):
    """创建Gradio应用界面"""
    
    # 注册功能
    def register_speaker(audio_file, speaker_name):
        """注册说话人"""
        import time
        import os
        
        if audio_file is None:
            return "❌ 请上传音频文件", get_registered_list()
        
        if not speaker_name or speaker_name.strip() == "":
            return "❌ 请输入说话人姓名", get_registered_list()
        
        # 检查文件是否存在
        if not os.path.exists(audio_file):
            return "❌ 音频文件不存在，请重新上传", get_registered_list()
        
        # 检查文件大小（确保文件已完全上传）
        max_wait = 10  # 最多等待10秒
        file_size = 0
        for _ in range(max_wait):
            try:
                current_size = os.path.getsize(audio_file)
                if current_size > 0 and current_size == file_size:
                    # 文件大小稳定，说明上传完成
                    break
                file_size = current_size
                time.sleep(0.5)
            except:
                time.sleep(0.5)
        
        # 再次确认文件大小
        if file_size == 0:
            return "❌ 音频文件为空，请重新上传", get_registered_list()
        
        # 执行注册
        success, message = sv_system.register_speaker(audio_file, speaker_name)
        
        if success:
            return f"✅ {message}", get_registered_list()
        else:
            return f"❌ {message}", get_registered_list()
    
    # 获取已注册人员列表
    def get_registered_list():
        """获取已注册人员列表"""
        speakers = sv_system.get_registered_speakers()
        if len(speakers) == 0:
            return "暂无注册用户"
        return "\n".join([f"👤 {i+1}. {name}" for i, name in enumerate(speakers)])
    
    # 音频上传状态监听
    def on_audio_change(audio_file):
        """当音频文件变化时更新状态"""
        import os
        if audio_file is None:
            return "等待上传音频..."
        if not os.path.exists(audio_file):
            return "⏳ 音频处理中，请稍候..."
        file_size = os.path.getsize(audio_file)
        if file_size == 0:
            return "⏳ 音频处理中，请稍候..."
        return f"✓ 音频已就绪（{file_size/1024:.1f} KB），可以开始验证"
    
    # 身份验证功能
    def verify_speaker(audio_file, threshold):
        """验证说话人身份"""
        import time
        import os
        
        # 检查音频文件是否存在
        if audio_file is None:
            return "❌ 请上传音频文件或录制音频", "", 0.0, "等待上传音频..."
        
        # 检查文件是否存在且可读
        if not os.path.exists(audio_file):
            return "❌ 音频文件不存在，请重新录音或上传", "", 0.0, "文件不存在"
        
        # 检查文件大小（确保文件已完全上传）
        max_wait = 10  # 最多等待10秒
        file_size = 0
        for i in range(max_wait):
            try:
                current_size = os.path.getsize(audio_file)
                if current_size > 0 and current_size == file_size:
                    # 文件大小稳定，说明上传完成
                    break
                file_size = current_size
                time.sleep(0.5)
            except:
                time.sleep(0.5)
        
        # 再次确认文件大小
        if file_size == 0:
            return "❌ 音频文件为空，请重新录音或上传", "", 0.0, "文件为空"
        
        # 执行验证
        success, matched_name, similarity, message = sv_system.verify_speaker(audio_file, threshold)
        
        # 更新状态
        status = "✅ 验证完成" if success else "⚠️ 验证完成"
        
        # 直接返回简洁的消息
        return message, matched_name, similarity, status
    
    # 清空数据库
    def clear_all_speakers():
        """清空所有注册用户"""
        success, message = sv_system.clear_database()
        return message, get_registered_list()
    
    # 构建界面
    with gr.Blocks(
        title="2025年FPGA创新设计大赛——安路赛道",
        theme=gr.themes.Soft()
    ) as demo:
        
        # 标题
        gr.Markdown(
            """
            # 🎙️ 2025年FPGA创新设计大赛——安路赛道
            ## 说话人身份确认系统
            
            **系统功能：** 通过声纹识别技术进行身份注册和验证
            
            **使用流程：**
            1. 在"身份注册区"上传音频并输入姓名进行注册
            2. 在"注册人员信息区"查看已注册用户
            3. 在"身份检测区"上传音频或录音进行身份验证
            4. 在"身份认证结果区"查看验证结果
            """
        )
        
        with gr.Row():
            # 左侧：注册和人员信息
            with gr.Column(scale=1):
                # 3.1 身份注册区
                gr.Markdown("### 📝 身份注册区")
                with gr.Group():
                    register_audio = gr.Audio(
                        label="上传音频文件（支持 mp3/wav/m4a 等格式，建议3-10秒）",
                        type="filepath",
                        sources=["upload"]
                    )
                    register_name = gr.Textbox(
                        label="输入说话人姓名",
                        placeholder="请输入姓名...",
                        lines=1
                    )
                    register_btn = gr.Button("✅ 注册", variant="primary", size="lg")
                    register_result = gr.Textbox(
                        label="注册结果",
                        lines=3,
                        interactive=False
                    )
                
                gr.Markdown("---")
                
                # 3.2 注册人员信息区
                gr.Markdown("### 👥 注册人员信息区")
                with gr.Group():
                    registered_list = gr.Textbox(
                        label="已注册用户列表",
                        value=get_registered_list(),
                        lines=10,
                        interactive=False
                    )
                    with gr.Row():
                        refresh_btn = gr.Button("🔄 刷新列表", size="sm")
                        clear_btn = gr.Button("🗑️ 清空数据库", size="sm", variant="stop")
            
            # 右侧：身份检测和结果
            with gr.Column(scale=1):
                # 3.3 身份检测区
                gr.Markdown("### 🔍 身份检测区")
                with gr.Group():
                    verify_audio = gr.Audio(
                        label="上传音频或在线录音（支持 mp3/wav/m4a 等格式）",
                        type="filepath",
                        sources=["microphone", "upload"]
                    )
                    
                    # 阈值设置
                    threshold_slider = gr.Slider(
                        minimum=0.0,
                        maximum=1.0,
                        value=0.6,
                        step=0.01,
                        label="相似度阈值",
                        info="当相似度 ≥ 阈值时判定为认证成功。建议范围：0.55-0.75"
                    )
                    
                    # 状态提示
                    status_text = gr.Textbox(
                        label="状态",
                        value="等待上传音频...",
                        interactive=False,
                        lines=1
                    )
                    
                    verify_btn = gr.Button("🔍 开始验证", variant="primary", size="lg")
                
                gr.Markdown("---")
                
                # 3.4 身份认证结果区
                gr.Markdown("### 📊 身份认证结果区")
                with gr.Group():
                    result_text = gr.Textbox(
                        label="认证结果",
                        lines=8,
                        interactive=False
                    )
                    with gr.Row():
                        result_name = gr.Textbox(
                            label="识别身份",
                            interactive=False,
                            scale=2
                        )
                        result_similarity = gr.Number(
                            label="相似度",
                            precision=4,
                            interactive=False,
                            scale=1
                        )
        
        # 使用说明
        gr.Markdown(
            """
            ---
            ### 📖 使用说明
            
            **注册步骤：**
            1. 在"身份注册区"点击上传按钮，选择本地音频文件
            2. 支持格式：**mp3, wav, m4a, flac, ogg** 等常见音频格式
            3. 系统会自动转换为单声道 16kHz 格式
            4. 输入说话人的姓名
            5. 点击"注册"按钮完成注册
            6. 在"注册人员信息区"可以看到新注册的用户
            
            **验证步骤：**
            1. 在"身份检测区"可以选择：
               - 点击麦克风图标进行在线录音
               - 点击上传按钮选择本地音频文件（支持 mp3/wav/m4a 等格式）
            2. **录音后请稍等**，等"状态"显示"✓ 音频已就绪"后再验证
            3. 系统会自动转换为单声道 16kHz 格式
            4. 调整"相似度阈值"（可选，默认0.6）
            5. 点击"开始验证"按钮
            6. 系统会自动与数据库中的所有用户进行比对
            7. 在"身份认证结果区"显示验证结果
            
            **阈值说明：**
            - **作用**：相似度达到或超过阈值时，判定为认证成功
            - **默认值**：0.6（平衡准确性和召回率）
            - **建议范围**：
              - 0.55-0.65：宽松模式，更容易通过认证（适合录音质量较差的场景）
              - 0.65-0.75：标准模式，平衡准确性（推荐）
              - 0.75-0.85：严格模式，降低误识别率（适合安全要求高的场景）
            
            **注意事项：**
            - 建议录音时长为 3-10 秒，包含清晰的语音内容
            - **录音完成后请等待状态显示"✓ 音频已就绪"再点击验证按钮**
            - 尽量在安静环境下录音，避免背景噪音
            - 支持多种音频格式：**mp3, wav, m4a, flac, ogg** 等
            - 系统会自动将音频转换为单声道 16kHz 格式
            - 系统支持多用户注册，每个用户的声纹特征会保存在数据库中
            
            ### 🔧 技术说明
            
            - **声纹提取模型：** CAM++ 模型（ONNX格式）
            - **音频处理：** 自动转换为单声道 16kHz
            - **支持格式：** mp3, wav, m4a, flac, ogg 等
            - **特征提取：** Fbank 80维声学特征
            - **相似度计算：** 余弦相似度（范围：0-1，越大越相似）
            - **默认阈值：** 0.6
            """
        )
        
        # 事件绑定
        # 注册按钮
        register_btn.click(
            register_speaker,
            inputs=[register_audio, register_name],
            outputs=[register_result, registered_list]
        )
        
        # 音频变化监听（实时更新状态）
        verify_audio.change(
            on_audio_change,
            inputs=[verify_audio],
            outputs=[status_text]
        )
        
        # 验证按钮
        verify_btn.click(
            verify_speaker,
            inputs=[verify_audio, threshold_slider],
            outputs=[result_text, result_name, result_similarity, status_text]
        )
        
        # 刷新列表按钮
        refresh_btn.click(
            lambda: get_registered_list(),
            inputs=None,
            outputs=[registered_list]
        )
        
        # 清空数据库按钮
        clear_btn.click(
            clear_all_speakers,
            inputs=None,
            outputs=[register_result, registered_list]
        )
    
    return demo


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="说话人确认系统 Gradio Demo")
    parser.add_argument('--host', type=str, default='0.0.0.0', help='服务器地址')
    parser.add_argument('--port', type=int, default=6011, help='服务器端口')
    parser.add_argument('--share', default=True, help='是否创建公共分享链接')
    parser.add_argument('--model_path', type=str, 
                       default='models/sv/campplus_emb.onnx',
                       help='ONNX模型路径')
    parser.add_argument('--db_path', type=str, 
                       default='speaker_db.json',
                       help='说话人数据库路径')
    
    args = parser.parse_args()
    
    # 初始化说话人确认系统
    print("正在加载说话人确认系统...")
    sv_system = SpeakerVerificationSystem(args.model_path, args.db_path)
    print("系统加载完成！")
    
    # 创建Gradio应用
    print("正在构建Web界面...")
    demo = create_app(sv_system)
    
    # 启动服务
    print(f"启动服务器: http://{args.host}:{args.port}")
    if args.share:
        print("正在生成公共分享链接...")
    
    demo.queue().launch(
        server_name=args.host,
        server_port=args.port,
        share=args.share,
        show_error=True
    )


if __name__ == '__main__':
    main()

