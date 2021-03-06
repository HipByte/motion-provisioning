describe "MobileProvision" do
  [:ios, :tvos, :mac].each do |platform|
    describe platform.to_s do
      [:distribution, :adhoc, :development, :development_free].each do |type|
        free = type == :development_free
        next if platform == :mac && free

        describe type.to_s.capitalize, platform: platform.to_s, type: type.to_s, free: free do

          type = :development if type == :development_free
          cert_type = type == :development ? :development : :distribution
          cert_platform = platform == :mac ? :mac : :ios

          let(:bundle_id) { "com.example.myapp" }

          before do
            delete_certificate(SPEC_CERTIFICATES[platform][:development][:name])
            delete_certificate(SPEC_CERTIFICATES[platform][:distribution][:name])
            MotionProvisioning::Certificate.new.import_file("spec/fixtures/#{cert_platform}_development_private_key.p12")
            MotionProvisioning::Certificate.new.import_file("spec/fixtures/#{cert_platform}_development_certificate.cer")
            MotionProvisioning::Certificate.new.import_file("spec/fixtures/#{cert_platform}_distribution_private_key.p12")
            MotionProvisioning::Certificate.new.import_file("spec/fixtures/#{cert_platform}_distribution_certificate.cer")
            FileUtils.cp("spec/fixtures/#{cert_platform}_development_certificate.cer", MotionProvisioning.output_path)
            FileUtils.cp("spec/fixtures/#{cert_platform}_distribution_certificate.cer", MotionProvisioning.output_path)
            stub_list_apps(platform, exists: true, free: free)
            stub_list_certificates(platform, type, exists: true)
          end

          def mobileprovision_path(bundle_id, platform, type)
            File.join(MotionProvisioning.output_path, "#{bundle_id}_#{platform}_#{type}_provisioning_profile.mobileprovision")
          end

          it "can use cached .mobileprovision that has not yet expired" do
            cert = SPEC_CERTIFICATES[platform][cert_type][:content]
            mobileprovision = File.read("spec/fixtures/#{platform}/#{type}_provisioning_profile.mobileprovision").gsub('{certificate}', Base64.encode64(cert))
            mobileprovision.sub!(/<key>ExpirationDate<\/key>\n\t<date>(.+)<\/date>/, "<key>ExpirationDate</key>\n\t<date>#{DateTime.now.next_year.iso8601}</date>")
            File.write(mobileprovision_path(bundle_id, platform, type), mobileprovision)

            path = MotionProvisioning.profile(bundle_identifier: bundle_id,
              platform: platform,
              app_name: "My App",
              type: type,
              free: free)
            expect(path).to eq(mobileprovision_path(bundle_id, platform, type))
          end

          it "exits if the certificate file is not present" do
            FileUtils.rm("#{MotionProvisioning.output_path}/#{cert_platform}_#{cert_type}_certificate.cer")
            expect(lambda {
              MotionProvisioning.profile(bundle_identifier: bundle_id,
                platform: platform,
                app_name: "My App",
                type: type,
                free: free)
            }).to raise_error SystemExit
          end

          it "can create new .mobileprovision" do
            stub_list_profiles(platform, type, exists: false, free: free)
            stub_list_devices_free(platform) if free
            stub_create_profile(platform, type)
            stub_download_profile(platform, type, free: free)

            path = MotionProvisioning.profile(bundle_identifier: bundle_id,
              platform: platform,
              app_name: "My App",
              type: type,
              free: free)
            expect(path).to eq(mobileprovision_path(bundle_id, platform, type))
          end

          it "can download existing .mobileprovision" do
            stub_create_profile(platform, type) if type == :adhoc
            stub_list_profiles(platform, type, exists: true, free: free)
            stub_download_profile(platform, type, free: free)

            path = MotionProvisioning.profile(bundle_identifier: bundle_id,
              platform: platform,
              app_name: "My App",
              type: type,
              free: free)
            expect(path).to eq(mobileprovision_path(bundle_id, platform, type))
          end

          it "can repair existing .mobileprovision" do
            stub_list_profiles(platform, type, invalid: true, free: free)
            stub_list_devices_free(platform) if free
            stub_create_profile(platform, type) if type == :adhoc
            stub_repair_profile(platform, type)
            stub_download_profile(platform, type, free: free)

            path = MotionProvisioning.profile(bundle_identifier: bundle_id,
              platform: platform,
              app_name: "My App",
              type: type,
              free: free)
            expect(path).to eq(mobileprovision_path(bundle_id, platform, type))
          end
        end

      end
    end
  end
end
