describe 'activerecord-refresh_connection' do
  shared_context 'refresh_connection is disabled' do
    before do
      start_rails(rails_version)
    end
  end

  shared_context 'refresh_connection is enabled' do
    before do
      start_rails(rails_version, 'ENABLE_REFRESH_CONNECTION' => '1')
    end
  end

  shared_examples 'connected after request' do
    it do
      send_request
      threads = processlist(rails_database)
      expect(threads.length).to be >= 1
    end
  end

  shared_examples 'disconnected after request' do
    it do
      send_request
      threads = processlist(rails_database)
      expect(threads.length).to eq(0)
    end
  end

  shared_examples 'connected until end of the request' do
    it do
      script = <<-EOS
        (1..3).map do
          sleep 1
          Item.find_by_sql('SHOW PROCESSLIST').to_a
        end
      EOS

      json = run_script(script)
      threads_list = JSON.parse(json)

      id_list = threads_list.map {|threads|
        threads.select {|i| i['db'] == rails_database }.map {|i| i['Id'] }
      }.flatten

      expect(id_list.length).to eq(3)
      expect(id_list.uniq.length).to eq(1)
    end
  end

  context 'when rails 3.2' do
    let(:rails_version) { 3.2 }
    let(:rails_database) { 'rails32_dummy' }

    context 'when refresh_connection is disabled' do
      include_context 'refresh_connection is disabled'
      it_behaves_like 'connected after request'
    end

    context 'when refresh_connection is enabled' do
      include_context 'refresh_connection is enabled'
      it_behaves_like 'disconnected after request'
      it_behaves_like 'connected until end of the request'
    end
  end

  context 'when rails 4.0' do
    let(:rails_version) { 4.0 }
    let(:rails_database) { 'rails40_dummy' }

    context 'when refresh_connection is disabled' do
      include_context 'refresh_connection is disabled'
      it_behaves_like 'connected after request'
    end

    context 'when refresh_connection is enabled' do
      include_context 'refresh_connection is enabled'
      it_behaves_like 'disconnected after request'
      it_behaves_like 'connected until end of the request'
    end
  end
end
