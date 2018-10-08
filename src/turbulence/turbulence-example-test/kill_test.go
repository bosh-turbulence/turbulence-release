package example_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	tubclient "github.com/bosh-turbulence/turbulence/client"
	tubinc "github.com/bosh-turbulence/turbulence/incident"
	tubsel "github.com/bosh-turbulence/turbulence/incident/selector"
	tubtasks "github.com/bosh-turbulence/turbulence/tasks"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

var _ = Describe("Kill", func() {
	var (
		client tubclient.Turbulence
	)

	BeforeEach(func() {
		logger := boshlog.NewLogger(boshlog.LevelNone)
		config := tubclient.NewConfigFromEnv()
		client = tubclient.NewFactory(logger).New(config)
	})

	It("kills dummy deployment's z1", func() {
		req := tubinc.Request{
			Tasks: tubtasks.OptionsSlice{
				tubtasks.KillOptions{},
			},

			Selector: tubsel.Request{
				Deployment: &tubsel.NameRequest{Name: "dummy"},

				AZ: &tubsel.NameRequest{
					Name: "z1",
				},
			},
		}

		{ // Check that kill kills all z1 instances
			inc := client.CreateIncident(req)
			inc.Wait()

			Expect(inc.HasTaskErrors()).To(BeFalse())

			tasks := inc.TasksOfType(tubtasks.KillOptions{})
			Expect(tasks).To(HaveLen(4))

			for _, t := range tasks {
				Expect(t.Instance().AZ).To(Equal("z1"))
			}
		}
	})
})
