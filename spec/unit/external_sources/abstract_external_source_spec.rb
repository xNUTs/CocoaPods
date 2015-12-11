require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe ExternalSources::AbstractExternalSource do
    before do
      dependency = Dependency.new('Reachability', :git => fixture('integration/Reachability'))
      @subject = ExternalSources.from_dependency(dependency, nil)
      config.sandbox.prepare
    end

    #--------------------------------------#

    describe 'In general' do
      it 'compares to another' do
        dependency_1 = Dependency.new('Reachability', :git => 'url')
        dependency_2 = Dependency.new('Another_name', :git => 'url')
        dependency_3 = Dependency.new('Reachability', :git => 'another_url')

        dependency_1.should.be == dependency_1
        dependency_1.should.not.be == dependency_2
        dependency_1.should.not.be == dependency_3
      end

      it 'fetches the specification from the remote stores it in the sandbox' do
        config.sandbox.specification('Reachability').should.nil?
        @subject.fetch(config.sandbox)
        config.sandbox.specification('Reachability').name.should == 'Reachability'
      end
    end

    #--------------------------------------#

    describe 'Subclasses helpers' do
      it 'pre-downloads the Pod and stores the relevant information in the sandbox' do
        @subject.expects(:validate_podspec).with { |spec| spec.name.should == 'Reachability' }
        @subject.send(:pre_download, config.sandbox)
        path = config.sandbox.specifications_root + 'Reachability.podspec.json'
        path.should.exist?
        config.sandbox.predownloaded_pods.should == ['Reachability']
        config.sandbox.checkout_sources.should == {
          'Reachability' => {
            :git => fixture('integration/Reachability'),
            :commit => '4ec575e4b074dcc87c44018cce656672a979b34a',
          },
        }
      end

      describe 'podspec validation' do
        before do
          @podspec = Pod::Specification.from_file(fixture('spec-repos') + 'master/Specs/JSONKit/1.4/JSONKit.podspec.json')
        end

        it 'returns a validator for the given podspec' do
          validator = @subject.send(:validator_for_podspec, @podspec)
          validator.spec.should == @podspec
        end

        before do
          @validator = mock('Validator')
          @validator.expects(:quick=).with(true)
          @validator.expects(:allow_warnings=).with(true)
          @validator.expects(:ignore_public_only_results=).with(true)
          @validator.expects(:validate)
          @subject.stubs(:validator_for_podspec).returns(@validator)
        end

        it 'validates with the correct settings' do
          @validator.expects(:validated?).returns(true)
          @subject.send(:validate_podspec, @podspec)
        end

        it 'raises when validation fails' do
          @validator.expects(:validated?).returns(false)
          @validator.stubs(:results_message).returns('results_message')
          @validator.stubs(:failure_reason).returns('failure_reason')
          should.raise(Informative) { @subject.send(:validate_podspec, @podspec) }.
            message.should.include "The `Reachability` pod failed to validate due to failure_reason:\nresults_message"
        end
      end
    end
  end
end
